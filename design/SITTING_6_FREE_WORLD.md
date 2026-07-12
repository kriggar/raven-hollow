# SITTING #6 — the free-assets world (2026-07-12)

41 fresh 4K one-shots (post castle-v2/towers/graves/props waves; shots PRE-DATE roads v3 + sea v2 — road-skin and sea-band findings partially stale).
14 inspector agents + adversarial verify (2 verify batches lost to session limits: iron_vein/last_hearth/ledger_roads, famine_fields/finalized_fields/gravemark_tundra — their findings unverified, not listed).
Confirmed: 29 CRITICAL / 84 MAJOR / 47 MINOR.

## CRITICAL
### [bloodroad] Stray palette-foreign tree sprite floating on void at map origin
- where: extreme upper-left corner; orig px ~(430-580, 0-155)
- detail: A lush bright-green deciduous tree with a solid maroon shadow blob sits at the extreme top-left corner, more than half of it OUTSIDE the ground bounds on the grey void. It is the classic asset-spawned-at-origin bug (the same artifact appears in canal_maze and, as a rock, in bloodstone_pit). Its saturated green also violates the zone's ashen palette.
- fix: Find the prop spawner emitting a default/origin-positioned instance and delete it; add a bounds assert (no prop with footprint outside ground rect).

### [bloodroad] Ghost semi-transparent fence rows floating east of the road
- where: center of map, ~60px east of road; orig px ~(1945-1985, 1210-1235)
- detail: Two rows of pale fence posts rendered at roughly 30% alpha float in open ground just east of the road. Reads as a build-preview ghost or a decal with a broken modulate — clearly unfinished art, visible even at ambient exposure.
- fix: Restore full alpha with a proper fence sprite and dress it into a cluster, or delete the instance.

### [bloodstone_pit] Stray rock formation floating on void at map corner
- where: extreme upper-left corner; orig px ~(845-900, 10-58)
- detail: A dark boulder-cluster sprite sits at the extreme top-left corner with over half its body hanging outside the cave floor onto the grey void — same spawn-at-origin artifact class as the other two zones.
- fix: Delete/relocate the origin-spawned instance; add the out-of-bounds prop assert.

### [bloodstone_pit] Two ghost stud/post-row fragments floating on the cave floor
- where: just south of the pit, flanking the path; orig px (1873-1907, 930-945) and (2110-2127, 930-947)
- detail: Two miniature semi-transparent grids of pale posts (two rows of ~6 bars each, ~30x15px) float on bare floor west and east of the path below the pit — same broken-alpha ghost-fence class as bloodroad's. They read as debug markers at any exposure.
- fix: Remove them or replace with full-alpha props; hunt the shared placement script that emits these ghosts in multiple zones.

### [canal_maze] Stray tree sprite floating on void at map origin
- where: extreme upper-left corner; orig px ~(430-475, 0-38); map corner is at ~(452,32)
- detail: Identical artifact to bloodroad: a green tree with a solid dark shadow blob at the extreme top-left, straddling the map corner with most of its body on the grey void outside the grass bounds.
- fix: Same origin-spawn bug as the other zones — remove instance, add bounds check in the painter pipeline.

### [dead_timber (systemic: also drowned_quarter, eastern_ridges)] Stray tree sprite floating outside the NW map corner in all three zone shots
- where: extreme top-left corner of every shot, orig px ≈ (430-540, 0-95)
- detail: An identical green deciduous tree with its dark shadow blob renders on the grey out-of-bounds void just past the top-left corner of the playable area in dead_timber, drowned_quarter AND eastern_ridges. It is a floating fragment beyond the zone boundary — almost certainly a deco spawned at/near world origin before the zone offset is applied. Classic debug-art leak visible from any zoomed-out view.
- fix: Find the prop instantiated at ~(0,0)/negative world coords and delete or re-parent it; add a boot validator that flags any deco whose AABB falls outside the zone rect.

### [dead_timber (systemic: also drowned_quarter, eastern_ridges)] Dirt roads are razor-straight full-map strips of flat colour-block tiles (greybox read)
- where: dead_timber full width orig y≈1100-1180; drowned_quarter vertical strip orig x≈1930-2010 full height + horizontal strip y≈1105-1180; eastern_ridges full width y≈1085-1170
- detail: The dirt artery in every zone is a ~2-tile band of untextured flat-brown rectangles with randomly sprinkled darker accent rectangles that read as a visible block grid (wallpaper rule 9). Both edges are razor-straight with zero blending into grass (rule 10). The polyline has literally zero bends across 2900px (rule 25 'ban the straight road') — the only direction changes are hard one-tile staircase jogs at segment joints: dead_timber has an offset joint at orig x≈1315; drowned_quarter has a mid-strip step at orig x≈2520 (two misaligned rows overlapping); eastern_ridges ends with a step-down and abrupt dark-tile shift right at the east gate (orig ≈3280-3350, 1085-1170) plus an orphan second row that dies at orig x≈3070. This is the spine of every zone and it reads as debug/greybox art.
- fix: Ship the queued LPC Terrains v7 autotile road v3; re-path every road with ≥3 interior waypoints and 20-40° kinks; edge-blend with tufts/pebbles/stains straddling the seam; kill the accent-tile block variation in favour of scattered decals.

### [drowned_quarter] West water body is a flat untextured navy rectangle with a razor shoreline
- where: entire west edge, orig ≈(455-575, 0-2140), shoreline at x≈575
- detail: The zone's only water — supposedly its identity feature — is a featureless flat navy fill running the full map height with a perfectly straight vertical shoreline where grass abuts water with zero bank, shore, or transition pixels. In ~2000px of coastline there is exactly one 2-dash wave decal. Reads as an unfinished rectangle/greybox, and it is the first thing visible from the whole west half.
- fix: Water texture/sheen tiles + animated wave decals; break the shoreline with an irregular bank strip, reeds, mud, docks and half-drowned props.

### [drowned_quarter] Ribbon road dead-ends INTO the water with a bare floating end cap
- where: west edge, orig ≈(430-520, 870-1000)
- detail: The grey ribbon starts on top of the flat navy water: its chamfered end cap is drawn floating on the water fill with no dock, bridge, ferry or ford art. A road that begins in open water violates gate-to-gate law and reads as a broken/floating road segment.
- fix: Terminate the ribbon at a dock/ferry landing set-piece on the bank, or route it to the west gate.

### [drowned_quarter] Vertical dirt path drawn semi-transparent OVER the ribbon at their crossing
- where: centre-south crossroads, orig ≈(2070-2155, 1470-1610)
- detail: Where the N-S dirt path crosses the ribbon, the path tiles are rendered translucently on top of it — both materials show through each other in an alpha-blended smear, with a few stray white item dots floating on the overlap. No bridge or junction art. This is a z-order/alpha bug read, visible from the zone's central crossroads.
- fix: Give the crossing a real bridge/ford tile set and fix the path layer's blend/z so road tiles are opaque.

### [lichenreach] Debug dot-grid rendered beside road
- where: center of map, just NE of the road; orig px (1946-1990, 535-560)
- detail: Two razor-straight rows of ~13 identical flat pale-grey squares, evenly spaced, sit on the dark slab ground just east of the road. Reads as unresolved autotile bits or a debug marker grid, not art. Nothing else in the zone shares this visual language.
- fix: Delete the marker grid; if a cobble inlay was intended, replace with an organic decal cluster at 0.35-0.7 alpha per Bible rule 9.

### [lichenreach] Broken white sprite: framed box + detached floating bar
- where: upper-right quarter, below NE lichen cluster; orig px (2610-2626, 510-545)
- detail: Below the NE lichen cluster there is a bright pure-white framed square with a second white bar floating ~8px below it, disconnected. Reads as a half-rendered two-part sprite (sign missing its post, or a placeholder). Pure white is also off the anchor palette (bone highlights must be earned).
- fix: Identify the intended prop and re-place a complete sprite, or remove both fragments.

### [lichenreach] Boulder prop hanging outside map bounds
- where: extreme top-left corner of the map; orig px (840-905, 8-55)
- detail: A large rock sprite sits on the NW map corner with more than half of its body (and its drop shadow) rendered over the grey out-of-bounds void.
- fix: Move the boulder fully inside the terrain, or delete it. Also see identical corner-spawn bugs in listening_steppe and morven_reach — likely one systemic near-origin placement bug.

### [morven_reach] River/west-channel junction is broken; river cap pokes into the void
- where: left-center; orig px (465-610, 1445-1560)
- detail: The diagonal river's west end overlaps the straight west water band instead of joining it: the river's brown banks are drawn ACROSS the band's open water, and the river's rounded end-cap (with bank outline) extends past the map's west boundary into the grey void. The crossing is unreadable — water crossing water with land banks in between.
- fix: Terminate the river at the band's shoreline with a proper confluence (bank taper, sheen fan), and clip all geometry to map bounds.

### [orange_fog] Debug/unfinished polylines (thin cyan curves) drawn on the ground
- where: lower-center, native px ~(1150-1500, 1330-1560) and a second batch at ~(2300-2530, 1350-1500)
- detail: Two clusters of 1px light-blue curved polylines connect small dark ground props (arrow/stake-like sprites). They read as pathfinding/trajectory debug rendering, not painterly art — no pixel texture, pure vector hairlines. Verified at 8x zoom.
- fix: Remove the debug line rendering (or replace with hand-painted rope/drag-mark decals if the vignette is intentional)

### [riverfork] The eponymous river does not exist in the zone
- where: entire frame; the grey band runs NW to SE, native ~(540,600) to (3290,1200)
- detail: Pixel scan of the full 4K shot finds ZERO water-blue pixels. The only linear feature is a warm-grey gradient ribbon (sampled RGB ~(85,80,75)) that reads as modern asphalt. There is no river and no fork anywhere — the zone-defining canon feature is absent, so the zone name/identity fails completely (rule 2).
- fix: Paint the actual forked river (water sheet + banks + sheen) or rename/re-theme; if the band is meant to BE the river, retexture it as water

### [riverfork] Grey band is placeholder-grade art: untextured anti-aliased gradient ribbon with visible end caps
- where: diagonal across center; west cap native ~(535-560, 575-660), east cap ~(3270-3300, 1140-1260)
- detail: The band has a smooth vector gradient (dark edge lines, light center streak), no cobble/dirt/water texture, uniform width, and is anti-aliased rather than pixel-art. Its west end terminates in a visible bevel CAP in open ground at the map edge instead of running off-map; the east end's cap overhangs past the ground boundary into the void. Reads as an unfinished spline placeholder, wildly off the painterly-pixel style anchor.
- fix: Replace with tiled pixel road/river material, blend edges per rule 10, and run both ends cleanly off-map

### [riverfork] Broken sprite: boat with baked-in rectangle of background water
- where: center-left, native px ~(1338-1392, 848-900)
- detail: A capsized-boat prop carries a semi-transparent flat blue-grey RECTANGLE under/behind the hull — leftover background from a failed alpha extraction (rule 20 discipline). At 15x the hard rectangle edges are unmistakable against the grass.
- fix: Re-extract the boat sprite with proper alpha trim and re-import

### [transcub_vale] Flat red debug square in open field
- where: right-center, ~600px E of the road; orig px (2237-2252, 989-1004)
- detail: A pure flat dark-red untextured square (~14x14px) sits on bare grass with a small bush kissing its right edge. Classic placeholder/debug rect — no texture, no palette grading, matches nothing in the asset library. Verified at 4x zoom.
- fix: Delete or replace with the intended prop (blanket/tarp?); if a vignette was intended, dress it (cloth sprite, dropped items, stain).

### [transcub_vale] Main road dead-ends in open grass
- where: bottom-center; road end at orig px (~1890-1925, 1840-1860); south map edge is at y≈2120
- detail: The zone's single road runs from the top gate but terminates mid-field ~350px short of the south map edge — it just stops in empty grass next to a tree. Bible rule 5/25: a road must never begin or end in open ground; this is the zone's spine failing its one job.
- fix: Extend the road to the south gate (with kinks per rule 25), or terminate it deliberately at a landmark (ruined gatehouse, collapsed bridge) that explains the stop.

### [transcub_vale] Tree sprite floating off-world at NW corner
- where: extreme top-left corner; orig px (430-478, 0-38)
- detail: A tree (with hard dark shadow blob) is spawned at the world origin, mostly outside the playable grass, floating on the grey void. Same fragment appears in all three zone shots — looks like a systemic painter bug placing an instance at (0,0).
- fix: Hunt the (0,0)-spawn in the painter/zone data and remove it in all zones; add a bounds assert so nothing spawns outside the map rect.

### [vetka] Flat lime-green debug bar at vendor display
- where: upper-right quarter, below the NE vendor house; orig px (2513-2537, 359-367)
- detail: A saturated pure-green horizontal bar (~20x3px) floats on grass next to the market-wheel display south of the vendor house. Flat color, no texture, hue outside the zone palette — reads as a debug line or broken sprite. Verified at 4x zoom.
- fix: Remove it or replace with the intended sprite (produce bundle on a crate, not raw pixels on grass).

### [vetka] Tree sprite floating off-world at NW corner
- where: extreme top-left corner; orig px (435-510, 0-35)
- detail: Same (0,0)-spawned tree fragment as transcub_vale: half a tree with a hard shadow blob sitting on the void outside the map corner.
- fix: Same systemic fix — remove origin spawn in painter output for every zone.

### [western_lowlands] River crosses the main road with no bridge or ford
- where: center-left; orig px (1230-1330, 1080-1135)
- detail: The grey river ribbon runs straight over the E-W dirt road; the road is faintly visible under the translucent water band. No bridge sprite, no ford stones, no bank break — the zone's two spines intersect in a completely unreadable way (is it crossable?). Verified at 4x zoom.
- fix: Place a bridge (or stone ford) asset at the crossing, break the river band under it, and blend road mouths onto the deck.

### [western_lowlands] Tree sprite floating off-world at NW corner
- where: extreme top-left corner; orig px (330-380, 0-35)
- detail: Third instance of the systemic (0,0) spawn: tree + shadow blob on the void outside the map corner.
- fix: Same systemic painter fix across all zones.

### [whisper_passes] Tree sprite floating outside the map in the void (top-left corner)
- where: extreme top-left corner, orig px ~(427-478, 0-35); ground fill starts at x~452
- detail: A full canopy tree with its dark soil/shadow base is rendered OUTSIDE the ground rectangle, straddling the map boundary into the grey void; the soil patch is razor-clipped by the map edge. Classic floating-fragment/broken-placement art.
- fix: Delete or move the tree inside the painted ground bounds; add a boundary check to the scatter pass so nothing spawns outside the terrain rect.

### [whisper_passes] Stray floating dark dash artifact beside the road-spire tip
- where: center of map, just NW of the on-road spire tip, orig px ~(2185-2200, 1042)
- detail: A flat dark horizontal line (~15x2 px) hovers in mid-air just left of the second spire's cone tip, attached to nothing. Reads as a debris pixel-fragment / half-sprite left by a bad stamp.
- fix: Delete the stray sprite/pixels; grep the scene for orphan nodes near (2190,1042).

### [whisper_passes] Grid of flat untextured brown rectangles at the burial-camp vignette
- where: north-center camp with fire/graves/bedrolls, orig px ~(1783-1827, 626-637)
- detail: Next to the two headstones sits a 2-row x ~7-column grid of tiny flat single-colour rectangles with zero texture or highlight. Even zoomed 6x they are unreadable placeholder ticks (possibly intended as wooden grave markers, but they render as debug squares in a perfect grid).
- fix: Replace with a real small-marker sprite (textured stick/plank crosses), jitter positions/scale per asymmetry law, or remove.

### [wilderness] West gate wall terminates in a razor vertical slice (half-built wall)
- where: west edge, wall orig ~(595-810, 1010-1170); cut end at x~810
- detail: The boundary gate wall runs east from the map edge, over the arch, then simply stops mid-wall with a clean vertical cut exposing the tile interior — no ruined end-cap, no rubble, no connection to the treeline. Reads as an unfinished tilemap run / half-sprite.
- fix: Cap the run with a ruined-end/tower piece or continue it into the forest edge with rubble taper.

## MAJOR
### [bloodroad] Ground speckle accents tile in a perfect visible grid across the entire zone (wallpaper)
- where: zone-wide; clearest in open field samples e.g. orig px (700-1200, 1100-1450)
- detail: The dark tuft/pebble breakup marks are baked one-per-tile into the ground sheet, producing rigid rows and columns of dots (~32px spacing) over the whole map. This is exactly the rule-9 stripe-grid defect: the entire canvas reads as dot-matrix wallpaper at any zoom.
- fix: Strip the accent from the base tile; scatter breakup as jittered decals (alpha 0.35-0.7, ~1 per 200k px^2) per Bible rule 9.

### [bloodroad] The zone's namesake road is a 1-tile-wide razor-straight dashed strip
- where: full-height vertical strip at orig x~1895-1935, y 0-2160
- detail: The Bloodroad itself is ~26-40px wide (single tile), runs perfectly vertical for the full 2160px map height with only single-tile jogs, has zero edge blending (razor slab edges, no straddling tufts/pebbles), and its dark 'wear' accent tiles are road-width squares that alternate like a checker/dashed debug line. Violates rules 5, 9, 10 and 25 (ban the straight road: needs >=3 waypoints, 80-160px lateral offsets, 20-40 degree kinks).
- fix: Repaint as a 2-3 tile wide polyline with kinks and lateral drift; demote accents to sparse decals; run the seam-blending pass on both edges.

### [bloodroad] Southern half of the zone has no anchors — two dead quadrants
- where: bottom half; e.g. orig px (450-1750, 1500-2150) and (2600-3600, 1400-2100)
- detail: Below mid-map there is nothing but tuft/rock confetti: the SW quadrant (~1300x650px) and SE quadrant contain no building, monument, camp, light or story cluster. Every anchor in the zone (ruined tower, stall, campfire, statue) sits in the upper half. Fails rule 7 (anchor per quadrant), rule 15 (curiosity sites) and the 40-second Witchbrook bar.
- fix: Add 1-2 story clusters per south quadrant (wreck, shrine, crime scene) with satellites, plus one authored quiet-quarter — not more confetti.

### [bloodroad] Flat untextured maroon blob prop with blood drip
- where: right-center, ~450px east of road; orig px (2390-2425, 690-745)
- detail: An isolated rounded-rectangle maroon shape over a black patch with a 1px red drip below it stands alone in open field. It has almost no internal texture and no readable silhouette (cart? altar? barrel?) — reads as placeholder art, and it is the only landmark for hundreds of px.
- fix: Replace with a finished prop (e.g. proper toppled cart + blood pool decal) and give it 2-3 satellites to make a vignette.

### [bloodstone_pit] Bloodstone 'veins' render as 1px blue debug polylines
- where: throughout the pit's middle third; samples orig px (2350,1180), (2500,1300), (1700,660), (2850,1290)
- detail: Dozens of thin uniform blue polylines with sharp kinks and small stake/tick endpoints radiate across the mid-map floor. They have no pixel-art weight, no glow falloff, no width variation — they read as vector debug lines or unfinished vein decals, badly off the painterly anchor (canon cave glow is teal lichen, not powder-blue hairlines).
- fix: Replace with painted crystal-vein decals (2-4px core, glow halo, broken segments) or delete and let lichen clusters carry the mineral read.

### [bloodstone_pit] The Pit itself is a flat black untextured ellipse
- where: map center; orig px (1860-1980, 772-845)
- detail: The zone's namesake centerpiece is a pure-black oval with no rim lip, no depth strata, no inner glow or falling-edge highlight — at any exposure it reads as an ellipse punched in the layer, placeholder-grade for 'the one image' the player should screenshot.
- fix: Paint a rim ring (worn stone lip + ember glow from below per canon), interior gradient with faint red strata, and scatter spill/rubble around the lip.

### [bloodstone_pit] South path is broken dashes on a razor-straight line
- where: orig x~1900-1960, y 960-2160; gap sample (1900-1960, 1380-1455)
- detail: The only road runs dead-vertical from the pit to the south exit with single-tile jogs, and its fill is interrupted by missing chunks (e.g. a full gap around orig y 1380-1455 and rectangular notches near y 1450-1530), so it reads as disconnected floating patches rather than a worn trail. Edges are razor with zero blending.
- fix: Make the fill continuous with organic worn edges, add 2-3 real bends, and blend both edges with rubble/dust straddle decals.

### [bloodstone_pit] Flagship lodge building has no approach — floats unconnected
- where: top-center; orig px (1805-2025, 370-510)
- detail: The large timber lodge north of the pit (the zone's biggest anchor) has no path, no breadcrumb props, and almost no perimeter dressing connecting it to the pit or the south road; the road network stops at the pit. Violates rules 5 (roads gate-to-gate spine), 27 (slot grammar) and 30 (breadcrumb the approach).
- fix: Extend the trail around the pit's west lip to the lodge door, add 3-5 lore breadcrumb props at 150-250px intervals, dress the facade corners in L-shapes.

### [bloodstone_pit] East and west flanks are dead zones; floor tile grid visible zone-wide
- where: east flank orig px ~(2450-3000, 500-1900); west-north ~(900-1400, 300-900); grid zone-wide
- detail: Roughly a quarter of the map on the east flank and a large west-north region contain nothing but bare cobble floor, and the large boulder-cobble floor tile repeats with its cell seams aligned to a visible grid across the whole zone (readable even at night exposure). Together they fail the Witchbrook density bar and rule 9.
- fix: Add mining-story clusters (abandoned rigs, cart tracks, bone middens) to each flank; break the floor grid with offset variant tiles and rubble/lichen decals across seams.

### [canal_maze] Main road dead-ends into the canal — no bridge, dock or crossing anywhere
- where: center of map; road terminus orig px ~(1943-1950, 1080-1107)
- detail: The east-west road slams flush into the canal's east bank and stops; the west bank has no road at all, and there is no bridge, pier, ramp or ferry post along the canal's entire 2160px length. Four rowboats float nearby but nothing marks a crossing, so the junction is unreadable and the whole west half hangs off no road spine (rule 5).
- fix: Add a dock/pier + ferry vignette (or a bridge) at the junction and continue at least a footpath west to serve the five west-bank buildings.

### [canal_maze] Zone is named canal_maze but contains one straight canal
- where: full-height channel at orig x~1888-1970, y 0-2160
- detail: A single razor-straight vertical channel with no branches, junctions, basins or locks — no maze whatsoever. Zone identity fails rule 2 (a random screen reads 'generic grass + ditch'), and the dead-straight full-height run violates the straight-road ban applied to waterways.
- fix: Rework into 2-3 branching channels with elbows and a basin, or rename/re-theme; at minimum add bends and lock/sluice set-pieces.

### [canal_maze] Road east of canal: checkerboard accent tiles and two step-misaligned joints
- where: orig y~1080-1140, x 1950-3400; step-joints at ~(2525,1105) and ~(2717,1110)
- detail: The dark 'wear' accents are full-width square tiles at ~50% density, making the road read as a corrupted tan/brown checkerboard; and the road band visibly steps ~20px vertically at two joints with razor cuts (segments not aligned), reading as floating misjoined pieces.
- fix: Rebuild as one continuous polyline; demote wear accents to sparse alpha decals; blend both edges per rule 10.

### [canal_maze] Canal edge treatment is inconsistent and shows layering seams
- where: along the canal; seam stripe sample orig px (1944, 1990-2140); bankless stretch at the junction (1888, 1080-1400)
- detail: Bank rendering changes arbitrarily along the run: dark carved banks on both sides near the top, a wide tan mud strip only north of the junction on the east side, bare razor grass-to-water contact at the junction's west side, and a 2-3px orange bank stripe pinched between water and grass along the lower east edge that reads as a misaligned texture seam. Water fill itself is long straight vertical bands (smeared gradient) with no ripple texture.
- fix: One consistent bank profile (dark cut + mud lip) for the full run, edge-straddling reed/stone decals at 20-30% frequency, and a proper water sheen texture.

### [canal_maze] Witchbrook-bar density failure: large dead grass regions and isolated buildings
- where: orig px ~(2900-3400, 60-500), (500-1700, 1650-2100), (450-1000, 1150-1550)
- detail: Multiple screen-sized regions are featureless olive grass: the top-right corner (~500x450px), the bottom-left quadrant (~1200x450px), and the center-left band. Buildings sit alone in empty fields with almost no yard clutter, paths or light; ground breakup is a barely-visible uniform speckle, so large shapes read flat.
- fix: Give every farmstead a yard cluster (fence L-shapes, cart, well, garden) plus connective footpaths; add 2 curiosity sites and 1 crime scene per the Bible; keep one authored quiet-quarter only.

### [dead_timber (also drowned_quarter)] Main grey ribbon artery is a smooth anti-aliased vector spline, not pixel art
- where: dead_timber diagonal ribbon from W edge (orig 450,1350) to NE (orig 3500,440); drowned_quarter ribbon from W water band (orig 450,900) to E edge (orig 3386,1660)
- detail: The wide blue-grey ribbon (the zone's other artery) is rendered as a smooth curved polygon with flat longitudinal colour bands and a bevelled dark edge — no pixel texture, no bank/shoulder treatment, no dithering. Its material is unreadable: it reads river from the blue banding but road from the NPCs/lamp posts on it. The anti-aliased curves clash hard against the 32px painterly sprites sitting on and beside it; at gameplay zoom it looks like an unfinished spline placeholder.
- fix: Replace with textured pixel road/river tiles (autotile), add bank transition strips, and commit to one material read (wheel ruts + stones if road; sheen + wave decals if water).

### [dead_timber] Dirt road x ribbon junction is broken: misaligned segments and no crossing art
- where: centre of zone, junction orig ≈ (2040-2170, 1180-1260); misaligned step orig x≈1315
- detail: The E-W dirt strip butts into the grey ribbon and resumes on the far side one tile higher — the west approach sits visibly lower than the east continuation, with the joint step landing right before the crossing. There is no bridge, ford, or junction treatment at all where the two arteries meet; the dirt tiles simply stop at the ribbon's bank and reappear on the other side. Unreadable crossing on the two most-travelled paths in the zone.
- fix: Add a bridge/ford set-piece at the crossing and re-align the two strip segments to one baseline.

### [dead_timber] Square castle tower reads as a flat green rectangle and sits on the road
- where: centre, just NW of the dirt/ribbon crossing, orig ≈ (1930-2060, 900-1035)
- detail: The tower_sq composite reads at gameplay zoom as an untextured moss-green square with a brown border — the top-down roof fill has almost no interior texture, so from the overview it is indistinguishable from a debug rect. Its south edge also sits directly on the ribbon's slab edge (violates the 60px road keep-clear), so the road visually clips under the building corner.
- fix: Retexture the tower roof fill (weathering, planks/slates, shadowed crenellation interior) or swap for the readable cone-roof round tower; nudge it ≥60px north of the road edge.

### [dead_timber (also drowned_quarter)] Bushes, scatter decals and props sitting ON the ribbon surface
- where: dead_timber SW ribbon segment orig ≈(845-875, 1240-1320) and crossing orig ≈(2350-2460, 980-1060); drowned_quarter orig ≈(690-715, 940-965)
- detail: Multiple ground props spawn on top of the ribbon artery: in dead_timber two green bushes and a grey lichen decal sit on the carriageway near the SW end (orig ≈845-875, 1240-1320) and a dead tree + wooden pole are planted on it at the north crossing (orig ≈2350-2460, 980-1060); in drowned_quarter a bush sits on the lower edge at orig ≈(690-715, 940-965). The ribbon's footprint is clearly not registered as keep-clear for the scatter system.
- fix: Register the ribbon polyline as a keep-clear region for vegetation/decal scatter and re-run the scatter pass.

### [dead_timber] Screen-scale dead zones and even confetti scatter across most of the zone
- where: worst void south-central, orig ≈(1900-2600, 1600-2050); secondary voids top-centre and east-centre
- detail: Verified at native res: the south-central region (orig ≈1900-2600 x 1600-2050) is a void of bare grass and tufts larger than a full gameplay screen; similar voids at top-centre (orig ≈1300-1900 x 100-450) and east-centre (orig ≈2900-3350 x 700-1050). Outside the road band, props are sprinkled as evenly-spaced singles (lone chairs at orig ≈3260-3310, 1135-1180; isolated red items; single trees) instead of 3-7-prop story clusters. Fails the 40-second rule and the Witchbrook density bar.
- fix: Author story clusters (logging camps, deadfall walls, stump fields with abandoned saws, drag-trails) into each void; consolidate confetti singles into clusters; keep ONE authored quiet-quarter only.

### [dead_timber (also eastern_ridges)] Snow-roofed cottage variant placed in green summer zones
- where: dead_timber village, orig ≈(2725-2845, 890-1055); eastern_ridges camp site, orig ≈(2615-2685, 770-870)
- detail: The LPC cottage with a white snow-drift roof (brown patches showing through like melt) is placed in dead_timber's roadside village and again at eastern_ridges' gravedigger camp. Both zones are green-grass summer palettes — a snow-covered roof is a wrong-season asset variant that instantly breaks biome cohesion and reads as a set-dressing mistake.
- fix: Swap to the non-snow roof variant of the same cottage (or recolor the roof toward thatch/shingle).

### [drowned_quarter] Black-hole tower-house: near-black silhouette, unreadable in daylight, zero satellites
- where: lower-left quadrant, orig ≈(1180-1330, 1395-1695)
- detail: The tall tower-house south of the ribbon is graded to near-pure black — at gameplay zoom it is a black blob against green (same family as the cat_dark_arch that was deleted from blestem for exactly this 'black-hole read'). It violates the no-pure-black/warm-the-darks law, and it stands alone on bare grass with no satellites, light, or approach dressing despite being a quadrant anchor.
- fix: Lift the mid-tones toward warm dark browns (parchment floor ~(0.07,0.05,0.03)), add a lit window or lantern, and dress its footprint (fence scraps, refuse, a path stub).

### [drowned_quarter] Zone identity failure: 'drowned quarter' reads as dry generic pasture
- where: zone-wide
- detail: Apart from the flat water band on the west edge, nothing in the zone says 'drowned': no flooded ruins, marsh pools, mud, reeds, stilt walkways, or waterlogged debris. Palette, ground sheet, and prop set are interchangeable with dead_timber — a random screenshot cannot answer which zone it is (rule 2 fail).
- fix: Add flooded-ruin set-pieces, standing-water pools with drowned props, mud/marsh ground decals radiating from the west bank.

### [drowned_quarter] Screen-scale dead zones in the NE, SE and west bands
- where: NE band orig ≈(2000-3380, 60-500); SE corner orig ≈(2100-3380, 1750-2140)
- detail: Verified at native res: the NE band (orig ≈2000-3380 x 60-500 — wider than a full gameplay screen) contains only scattered trees and zero POIs; the SE corner (orig ≈2100-3380 x 1750-2140) and the strip along the water band are similarly bare. The 40-second rule fails across roughly a third of the zone.
- fix: Drop 2-3 story clusters per void (drowned-cargo wreckage, fishing camp, ritual site), rotating POI types per the diversity rule.

### [eastern_ridges] Zone identity failure: 'eastern ridges' contains zero ridge/elevation features
- where: zone-wide
- detail: The zone is a uniformly flat green pasture — no cliffs, rock walls, scree, terraces, or elevation reads anywhere in the shot. Signature props are absent; palette and dressing are interchangeable with dead_timber and drowned_quarter. A random screenshot cannot identify the zone (rule 2 fail).
- fix: Introduce ridge-line rock formations/cliff bands (even faux 2D outcrop strips), scree scatter and hardy pines along E-W ridgelines; grade the grass drier/rockier.

### [eastern_ridges] NW quadrant is a full-screen dead zone with one POI; uniform pebble confetti elsewhere
- where: NW quadrant orig ≈(500-1700, 60-1000); SE band orig ≈(2400-3350, 1250-1700)
- detail: Verified at native res: orig ≈(500-1700 x 60-1000) — more than a full gameplay screen — contains a single market hut and otherwise only evenly-sprinkled small trees, rocks and tufts. The same uniform white-pebble/tuft sprinkle covers the whole zone at constant density (reads generated; violates story-cluster and density-gradient rules). Additional voids in the SE band orig ≈(2400-3350, 1250-1700).
- fix: Cluster the scatter into 3-7-prop stories (shepherd camp, cairn ring, wreck), thin the pebble confetti, and apply the density gradient (sparser near road, denser at the wild ring).

### [eastern_ridges] Ruined tower planted against the road's south edge — reads as standing ON the road
- where: centre-west, on the road, orig ≈(1385-1475, 1055-1235)
- detail: The grey crenellated ruin tower is placed so its top third overlaps the dirt road band; at gameplay zoom it reads as a structure sitting on the carriageway and the road spine disappears behind it (rule 6 occlusion + rule 5 keep-clear violation). The adjacent vignette (torch, dead pack animal, tables) is good — only the tower placement is broken.
- fix: Move the tower ~100-150px south so daylight shows between its crown and the road, or place it north of the road.

### [lichenreach] Road dead-ends in open ground at its north terminus
- where: top-center; grave at orig px (1902-1935, 395-442), road tip ~y=325, map edge y=30
- detail: The only road stops ~300px south of the north map edge with no gate, and the ember-grave set piece (white stone frame, glowing soil, headstone) sits dead-center ON the road slab at the terminus. Bible rule 5: roads run gate-to-gate and nothing sits on the slab; even as a deliberate vignette the road currently just evaporates into bare ground.
- fix: Extend the road to a north gate (or a readable terminus set piece flanking the slab) and shift the grave off the roadway.

### [lichenreach] Road overhangs the south terrain edge into the void
- where: bottom-center; orig px (1905-1940, 2126-2147)
- detail: Terrain ends at y≈2126 but road pixels continue to y≈2147, drawing road tile over the out-of-bounds grey (pixel-verified: road color (41,31,20) present below the terrain/void boundary).
- fix: Trim the road polyline to the terrain edge / south gate tile.

### [lichenreach] Razor-straight road violates ban-the-straight-road
- where: full map height, x≈1922, y 325-2147
- detail: The zone's single road runs ~1800px perfectly vertical at x≈1922 with only 1-tile stair jitter — no interior waypoints, no ±80-160px lateral offsets, no 20-40° kinks (learned rule 25). Reads generated at a glance.
- fix: Re-path with 3+ interior waypoints and hostile-biome sharp bends; hang the lichen clusters off the bends.

### [lichenreach] Vast dead zones — most of the map is empty slab ground
- where: zone-wide; worst: west band orig (850-1750, 100-2100) and east-center (2300-2950, 900-1800)
- detail: Outside ~10 lichen clusters, 2 torches and a handful of pebbles, the zone is bare. The entire west band (orig x 850-1750) holds 3 lichen clusters and nothing else across ~2000px of height; east band similar. Multiple screen-sized areas contain zero readable content — hard fail of the 40-second rule and the Witchbrook density bar, even for a dread zone (mood must come from what fills space, not absence).
- fix: Add canon dread dressing: bone scatters, dead trees, cairn rings, a murder vignette, collapsed structures; densify the outer ring per rule 31 and give every quadrant an anchor.

### [lichenreach] Hard-edged square gravel decals (visible sprite bounds)
- where: instances at orig px (1610,1067), (2366,120), (2130,733)
- detail: Perfect ~13px squares of gravel/noise texture dropped on the slab ground in at least three places — the decal's square bounds are fully legible, reading as placeholder patches rather than organic scatter.
- fix: Alpha-trim / feather these decals to irregular silhouettes, or swap for the round moss/gravel blob used elsewhere.

### [listening_steppe] Huge dead zones of featureless grass
- where: zone-wide; worst regions listed in detail
- detail: The map is ~2850x2090 with maybe 25 small POIs. The SW quarter below the camps (orig 500-1600, 1700-2120), the NE east half (2900-3340, 60-1000) and the NW top-left (500-1100, 60-600) are screen-sized-plus regions with literally nothing but flat grass and cloud shadow. 40-second rule fails in every direction of travel.
- fix: Add steppe-canon clusters (listening stones circles, herds, wind-worn shrines, wreck vignettes) on a density gradient toward the wild edges.

### [listening_steppe] Road skin: razor unblended edges + checkerboard accent tiles
- where: entire road length, x≈1905-1945
- detail: The sand road meets grass in a perfectly hard 1px seam for its whole length — zero tufts/pebbles/stain straddle (rule 10). Dark red-brown accent tiles drop in as full perfect squares at semi-regular intervals, reading as a checker pattern (rule 9 accent-tile defect).
- fix: Run the edge-blending pass (20-30% straddle frequency) and replace square accent tiles with irregular wear decals.

### [listening_steppe] Ground sheet is a near-flat monotone fill
- where: zone-wide ground
- detail: The grass is one uniform olive tone with extremely sparse 2px speck tufts (~1 per 200x200px) and no flowers, stones, soil patches or hue variation beyond cloud shadows. Ground-breakup layer of the Witchbrook density stack is effectively missing, and the saturated pea-green wash sits well off the anchor's muted, darks-dominant grade.
- fix: Add MultiMesh tuft/pebble/flower fields, soil and wear decals, then grade the sheet toward the anchor neutrals.

### [listening_steppe] Hamlet houses kissing — roof tip touches porch base
- where: lower-right quarter; houses at orig px (2215-2385, 1683-1863)
- detail: In the SE hamlet the north house and the house directly south of it are ~4-5px apart: the south house's roof apex nearly touches the north house's porch line. Violates the tangent ban (overlap >25% or separate >20px, never kiss) and the 180px building spacing rule; reads as a placement collision, not a packed district.
- fix: Nudge the south house 40-80px south/west and dress the gap (fence, woodpile).

### [morven_reach] West water band has no banks at all — flat blue strip
- where: entire west edge; orig px x 492-600, y 30-2128
- detail: The full-height west channel is a razor-straight rectangle of one flat slate tone: no shore/bank transition where it meets grass (hard 1px water-to-grass edge its entire ~2100px length), almost no sheen detail (one dash mark per ~250px). The diagonal river right next to it has proper banks and highlights, making the band read unfinished/placeholder.
- fix: Give it the same bank treatment as the river, bank-blending props (reeds, stones), and water sheen; consider a couple of inlets to kill the perfect straightness.

### [morven_reach] Junction inn and ivy mound sit on the road
- where: center of map at the road corner; inn orig px (1930-2075, 1000-1100), ivy mound (1990-2110, 1060-1120), road y≈1085-1105
- detail: At the L-junction the coaching inn's south face and a large leaf/ivy ground mound cover the horizontal road for ~150-240px — the road visually disappears under the building's skirt and the foliage blob, then reappears east of it. Violates rule 5 (nothing on the slab, 60px keep-clear) and breaks junction readability.
- fix: Shift the inn ~60-100px north, shrink/move the ivy decal off the slab, and let the road shoulder pass clean.

### [morven_reach] Road overhangs the east map edge into the void
- where: right edge, mid-height; orig px (3348-3362, 1085-1108)
- detail: Grass terminates at x≈3348 but the road strip continues to x≈3362, its final dark checker tile drawn fully over the out-of-bounds grey.
- fix: Clip the road at the east gate tile.

### [morven_reach] River overhangs the south terrain edge into the void
- where: bottom-center-left; orig px (1605-1700, 2128-2146)
- detail: The diagonal river (water + both banks) continues ~15px past the terrain edge (y≈2128) onto the void, tapering to a floating tip at y≈2145.
- fix: Clip the river polyline to the map boundary.

### [morven_reach] Both road segments are dead straight
- where: horizontal orig y≈1095, x 1930-3360; vertical orig x≈1935, y 1105-2140
- detail: The horizontal segment runs ~1400px at y≈1095 and the vertical segment ~1000px at x≈1935 with only 1-tile jitter — no waypoints, lateral offsets or kinks (learned rule 25). The road skin also shares the steppe defects: razor unblended grass seams and perfect-square dark checker accent tiles the whole length.
- fix: Re-path both segments with interior waypoints and bends; run the edge-blend pass and swap checker tiles for irregular wear.

### [morven_reach] SE dark manor is two mirrored copies of the same building glued together
- where: lower-right quarter; orig px (2805-3005, 1635-1775)
- detail: The burnt manor's left and right wings are pixel-mirrored duplicates of one two-story shopfront building (identical porches, shop awnings, ladders, ivy — mirrored), butted against a central barn facade. The symmetry/duplication is legible at gameplay zoom and the shopfront wings are incongruous for a ruined manor in open fields.
- fix: Vary one wing (different roofline, collapsed section, board-ups) or rebuild as an asymmetric composite; desaturate toward the parchment-floor darks rather than near-black.

### [morven_reach] Dead zones across the east and south
- where: regions listed; worst is NE east half
- detail: NE quad east of the chapel (orig 2700-3340, 60-1050) is essentially empty — one glowing grave and a few trees over multiple screens; likewise the south strip between river and road (900-1900, 1850-2120) and the SE corner below the dark manor (2400-3300, 1830-2120). Every quadrant needs its 40-second pull.
- fix: Dress with reach-canon clusters (fishing racks by the channel, field shrines, wreck/crime vignette) and put at least one anchor+satellites in the NE east half.

### [orange_fog] Grave planted directly ON the road slab
- where: center-left on the horizontal road, native px ~(1080-1170, 1060-1145)
- detail: An ornate headstone with dirt plot plus two flanking headstones sit on the E-W dirt road bed, breaking rule 5 (nothing on the road, 60px keep-clear). The dirt plot visibly overlaps the road tiles.
- fix: Move the grave cluster 80-120px south of the slab edge

### [orange_fog] Road is two razor-straight legs with a single 90-degree corner
- where: spans upper-center to mid-left; corner at native px ~(1930, 1090)
- detail: The entire road network is one dead-straight vertical run (x~1930, top edge to y~1090) and one dead-straight horizontal run (y~1090, x~460 to the corner) meeting at a right angle. No interior waypoints, no lateral offsets, no kinks (rule 25). Edges are razor with zero blending tufts/stains (rule 10), and the wear variation is full-tile dark squares that read as checker noise rather than painterly wear.
- fix: Re-lay the polyline with 3+ waypoints, +/-80-160px offsets, 20-40 degree kinks; add edge-straddling tufts/pebbles; replace square accent tiles with alpha decals

### [orange_fog] Zone identity missing: no orange fog anywhere in the shot
- where: entire frame
- detail: The zone's titular weather is absent — orange-ish pixels are ~2% of the frame (all trees/dirt). Fog patches render as same-hue olive smudges barely darker than the base grass. A random screenshot could be any generic field; fails rule 2 (zone identity in one screen). Judged within intended mood: the mood itself is not present.
- fix: Enable/retint the fog overlay toward the zone's orange accent so patches read as colored fog banks

### [orange_fog] Large dead zones; NE quadrant has no anchor at all
- where: bottom-left quarter, top-center band, and far bottom-right; NE quadrant overall
- detail: Bottom-left ~(450-1900, 1380-2130) is near-empty grass; top-center band ~(600-1900, 40-350) likewise; bottom-right ~(2900-3400, 1650-2130) has only 4-5 tufts. The NE quadrant's only feature is a single glowing grave — no building/monument/pit anchor (rule 7). Far below the Witchbrook density bar.
- fix: Add one anchor + satellites per empty quadrant and story clusters (camp, cairn ring, crime scene) at 1.0-1.4x mid-zone density

### [riverfork] Props and a building collide with the grey band
- where: trees native ~(690-760, 600-700); shop house ~(1550-1630, 795-905); stall/NPCs ~(2660-2790, 1150-1195)
- detail: A cluster of trees is planted directly ON the band (plus a bush mid-band); the roadside shop house sits on the band edge with its awning and goods stall overhanging the surface; further east a market stall and NPCs stand mid-band. Whether the band is road or river, footprint keep-clear (rules 5/11) is violated in three places.
- fix: Register the band's keep-clear rect and push trees/stall 60px+ off the surface; nudge the shop so only its stall front faces the edge

### [riverfork] Lone church belltower fragment with green matte fringe
- where: upper-left quarter, native px ~(1205-1250, 565-665)
- detail: A steeple-only sprite stands on bare grass: no church body, no foundation, no worn ground, no approach path. The silhouette has a dark-green fringe halo (baked background from imperfect extraction), visible at 10x along both sides. Reads as a half-building placeholder rather than an intentional ruin.
- fix: Either complete the vignette (ruined nave footprint, rubble, graves, worn ground) and clean the sprite's matte, or remove it

### [riverfork] Dirt road dead-ends in open ground and duplicates the grey band
- where: road spans native ~(1540, 985) to ~(3310, 1100); dead-end at west terminus
- detail: The patchy dirt road starts in plain grass west of the village (native ~x=1540) with no gate/POI terminus, violating rule 5 (gate-to-gate). It then runs parallel to the grey band 40-80px away for ~1700px, crossing it once — an unreadable double-transport corridor where neither line has hierarchy.
- fix: Merge the two into one road (or make the dirt a farm track hanging off the band at a clear junction) and end it at a gate or landmark

### [riverfork] Placeholder flat rectangles + noise swatch stamped on grass
- where: center, east of the village, native px ~(1600-1650, 925-950)
- detail: Two neat rows of six flat, untextured dark rectangles (no border, no shading) sit beside a ~9px square of dithered checker noise. At 20x they read as an unfinished garden plot or a debug stamp — textbook flat-colored-square placeholder.
- fix: Replace with a real tilled-plot prop (bordered soil rows) or delete

### [salt_fens] Ground is a visible wallpaper grid across the entire zone
- where: entire frame
- detail: One cracked-mud 'plate' tile repeats in an obvious ~64px grid over the whole map; identical cell borders line up in rows at every zoom level. This is the bible's #1 ground law violation (rule 9) and dominates every screenshot.
- fix: Rebuild the sheet as a uniform low-contrast fill and scatter the plate/crack motifs as alpha decals (~1 per 200k px2)

### [salt_fens] River is an untextured slate ribbon with razor edges and no banks
- where: spans full width of lower third, native y~1420-1600
- detail: Same placeholder ribbon asset as riverfork's grey band, tinted blue-grey: uniform width, straight segments with angular kinks, hard 1px dark edge, zero bank/shore blending, no ripple/sheen texture. Within the dusk mood it still reads as an asphalt strip, not fen water.
- fix: Retexture as water with painted banks, mudflat transition decals, reeds at 20-30% edge frequency

### [salt_fens] Road crosses the river with no bridge or ford
- where: center, native px ~(1900-1960, 1470-1560)
- detail: The N-S road runs straight under the river band and re-emerges on the far side; the ochre road is faintly visible THROUGH the translucent water. No bridge, planks, or ford stones — an unreadable crossing at the zone's most important intersection.
- fix: Place a bridge sprite (or ford stones) at the crossing and clip the road under it

### [salt_fens] River east end overhangs the map edge into the void
- where: far right edge, native px ~(3335-3380, 1495-1605)
- detail: The band terminates in a blunt squared cap that extends ~15-20px PAST the ground boundary, floating over the grey void, with its dark border wrapping the visible end. Floating segment + visible dead-end cap.
- fix: Trim the polyline to the map bounds so the band exits under the edge cleanly

### [salt_fens] Both roads are perfectly straight and axis-aligned for their full length
- where: vertical spine at native x~1930; horizontal at y~1090, left half
- detail: The N-S road is dead straight for ~2100px (x~1930, top edge to bottom edge); the E-W road is dead straight from the left edge to the T-junction (y~1090). No waypoints, offsets, or kinks (rule 25); razor edges with no blending (rule 10); wear accents are full dark squares in a checker pattern.
- fix: Re-lay both with lateral offsets and kinks; decal-based wear; blend edges into the mud

### [salt_fens] Salt pans are flat airbrushed ellipses (signature prop reads placeholder)
- where: left-center cluster, native px ~(950-1160, 1290-1460)
- detail: The zone's signature salt deposits are smooth cream ovals with anti-aliased soft edges, no crystalline rim, no interior texture beyond 2-3 white dashes — completely off the painterly-pixel style anchor. Verified at 7x.
- fix: Repaint as pixel-textured crusts: cracked white rim, dithered interior, briny center pool

### [salt_fens] Anchor-less dead zones over most of the east and south
- where: upper-right quarter and bottom-right quarter
- detail: NE region ~(2000-3800, 60-950) is bare wallpaper with a few zombies/graves and no anchor until the church at its extreme bottom edge (rule 7). SE below the river ~(1920-3350, 1630-2160) has two tree clumps and one campfire in ~1.5M px2. West band ~(500-1000, 300-1080) similar. The wallpaper repeat makes the emptiness read even louder.
- fix: One anchor + satellites per quadrant; rotate POI types along the roads (habitation/ritual/nature/wreckage)

### [transcub_vale] Open-grave prop placed ON the road
- where: center of map, on the road; orig px (1912-1942, 1470-1510)
- detail: The grey-framed open-grave asset (same sprite as the three-grave row at 2550,1740) straddles the road slab dead-center, blocking it. Rule 5: nothing sits on the road, 60px keep-clear. If this is the 'grave out of line' story beat, it has zero dressing (no mound, drag marks, lantern) to sell it as deliberate.
- fix: Move it 60px+ off the slab, or commit to the story beat: keep it on the road but add mound, shovel, drag-marks and make the road visibly detour around it.

### [transcub_vale] Road is ruler-straight for the entire map height
- where: map center, x≈1905, y 30-1855
- detail: The single road is a perfectly vertical line for ~1800px with only two 1-tile square jogs (y≈492, y≈820) that read as tiling errors, not bends. Direct violation of rule 25 (>=3 interior waypoints, ±80-160px lateral offsets, 20-40° kinks every 400-700px).
- fix: Re-lay the polyline with proper waypoints and lateral offsets; use bends to tease the inn and manors before delivering them.

### [transcub_vale] Road surface: dark checker accent tiles + razor edges
- where: entire road, x 1890-1925, y 30-1855
- detail: Full dark red-brown square tiles are mixed into the tan road at tile granularity, producing a dashed checkerboard down both edges (rule 9's banned accent-tile-in-sheet pattern). Road/grass transition is a razor line the whole length — zero straddling tufts/pebbles/stains (rule 10).
- fix: Make the road sheet a uniform fill; move wear/dirt accents to alpha decals (0.35-0.7) scattered off-grid; add a 20-30% edge-blending pass.

### [transcub_vale] Dead zone: entire SW quadrant is empty carpet
- where: bottom-left; orig px region ~(455-1890, 1600-2120)
- detail: From the west map edge to the road, south of the manors (~1450x420px+), there is nothing but flat grass, a handful of pebbles and one under-dressed campfire at (1385,1510). Fails the 40-second rule and the Witchbrook density bar; ground itself is a monotone sheet with almost no breakup decals.
- fix: Add 2-3 story clusters (camp with bedrolls/rack, cairn ring, wreck vignette), a quiet-quarter with heavy ground breakup + sway, and a vegetation wall along the south rim.

### [transcub_vale] Dead zone: eastern third has no anchor
- where: right third; orig px region ~(2820-3390, 100-1000)
- detail: The NE/E band (~570x900px) contains only scattered trees, rocks and the five-grave row — no building, monument, vent or pit. Rule 7 (every quadrant gets >=1 anchor with satellites) is broken for both east quadrants.
- fix: Place one anchor (shrine ruin, watchtower, sinkhole) with 2-5 satellites, and breadcrumb it from the road per rule 30.

### [transcub_vale] Five identical tombstones in an evenly-spaced row
- where: upper-right quarter; orig px (2655-2740, 735-790)
- detail: Five bright tombstones (two sprite variants repeated) stand in a near-perfect horizontal line with uniform ~10px gaps and aligned baselines, floating mid-field with no soil, fence, path or dressing. Reads as generated wallpaper (rule 8: organic must jitter; grids are reserved for meaning).
- fix: Jitter positions/scale, vary sprites, sink them in a dressed micro-graveyard (worn ground decal, dead grass, one leaning stone) or delete.

### [vetka] Central crossroads is an unreadable tile patchwork
- where: map center; orig px region (1700-2100, 980-1300)
- detail: The junction where the E-W road, the south road and the NE spur meet is a lumpy mass of misaligned light-tan and dark-brown full squares — arms change width (1 to 3 tiles), staircase diagonals collide, and no plaza/pad unifies the crossing. As the zone's hub moment it reads as smeared rectangles.
- fix: Author the junction deliberately: uniform road fill, a widened dressed pad (well, benches, lamp already present), decal wear at the mouths, and clean 45° staircase transitions.

### [vetka] Road surface: dark checker accent tiles + razor edges
- where: all roads; e.g. south road x≈1920-2040, y 1300-2160
- detail: Same defect family as transcub_vale: full dark squares embedded at tile granularity along all road arms (worst on the south road and NW diagonal), plus razor grass/road edges with no blending pass.
- fix: Uniform road fill + scattered wear decals + 20-30% edge-blend straddle props.

### [vetka] Dead zone: NW region is a ~700x650px empty field
- where: top-left quarter; orig px region (480-1250, 40-700)
- detail: From the west edge to x≈1250, y 40-700, there is only a stump, two tombstones and cloud shadows. No anchor, no cluster, no curiosity site — the largest single empty in the zone (rule 1/7 fail).
- fix: One anchor + satellites (charcoal burner camp, standing stone ring) and a quiet-quarter treatment with ground breakup for the rest.

### [vetka] Eastern hamlet is not connected to any road
- where: upper-right quarter; buildings at orig px (2475-2540,230-330), (2795-2885,685-825), (2950-3025,375-465)
- detail: The vendor house (~2500,280), the mill/workshop (~2840,750) and the fenced grave shrine (~2990,420) form the zone's richest content, but no road or path reaches any of them — the network stops at the house at (2218,1229). Roads are the spine (rule 5); this hamlet floats unreachable-looking in the field.
- fix: Extend a kinked spur from the junction NE through the hamlet, breadcrumb the approach (rule 30).

### [western_lowlands] River reads as flat grey asphalt, not water
- where: runs full map height, x≈1140-1330, y 15-2110
- detail: The full-length river is a uniform ~40px translucent grey band with two razor dark border lines and a lighter center stripe — like a highway with lane markings. No water texture, no sheen/ripple, no banks, no riverside dressing (reeds, rocks, mud transition) anywhere along ~2100px.
- fix: Swap to a water material with animated sheen, add bank transition tiles + reed/rock decals at 20-30% frequency, vary width at bends.

### [western_lowlands] Trees and bush planted ON the river
- where: lower-center; trees orig px (1250-1330, 1715-1800), bush (1252-1272, 1830-1860), vendor pot (1258-1275, 1706-1735)
- detail: A full tree (trunk + shadow) stands mid-water, a second tree cluster overlaps the east waterline, a bush sits on the river further south, and small items float on the band; the riverside vendor display's pot also overlaps the water edge. The water has no keep-clear rect (rule 11).
- fix: Register the river polygon as keep-clear, re-scatter the offenders onto the banks, keep one deliberate leaning-over-water tree if wanted (roots on land).

### [western_lowlands] E-W road is ruler-straight across the entire 3200px map
- where: spans full width at orig y≈1085-1125, x 340-3500
- detail: The dirt road runs edge-to-edge at constant y with zero interior waypoints or kinks — the most extreme 'straight road' violation of the three zones (rule 25). It also carries the same dark checker accent tiles and razor edges as the other zones.
- fix: Re-lay with 3+ waypoints and 20-40° kinks; uniform fill + wear decals + edge blending.

### [western_lowlands] Twin market stalls overlapping, ungraded bright white
- where: center-left of the hamlet area; orig px (2036-2125, 905-985)
- detail: Two copies of the same striped-canopy stall sprite are placed edge-to-edge with one offset upward so the canopies merge into a single glitched white mass — the brightest object on the map, hue/value far outside the anchor palette (bone highlights must be rare/earned). Tangent ban (rule 27) and duplicate-stamp both violated.
- fix: Keep one stall, rotate/offset a second variant 40-60px away if needed, and modulate the awning toward parchment/muted teal.

### [western_lowlands] Dead zone: northern band right of the river
- where: top-center/right; orig px region (2000-3450, 60-400)
- detail: The strip from the river to the NE corner above the hamlet (~1500x350px) is near-empty flat grass with a handful of tree singles — no cluster or curiosity between the two NE farmhouses.
- fix: Two story clusters on the rotation (nature → wreckage), plus ground-breakup decal fields.

### [whisper_passes] Zone-wide dead space — fails the 40-second rule catastrophically
- where: map-wide; worst: south-central band orig ~(500-3400, 1250-2100) and NE interior ~(2100-2900, 150-600)
- detail: ~70-80% of the map is bare flat olive grass with only noise speckle: the entire SW quadrant, the S-central band below the road, and the NE interior have no anchors, no verticals, no mid props, no ground breakup. POIs are isolated pinpricks separated by multiple screen-widths of nothing, and NOTHING hangs off the road (zero spurs, zero roadside dressing). This is the headline defect of the zone; nowhere near Witchbrook layered density.
- fix: Full set-dressing pass per bible rules 1/3/4/7/31: anchor + satellites per quadrant, story clusters of 3-7, density gradient rising to the outer ring, ground-breakup decals/tuft fields, and hang roadside content at varied depths off the road spine.

### [whisper_passes] Road is razor-straight for the entire map with glitchy half-width jogs
- where: full width of map, orig y~1055-1160, x 455-3420
- detail: The single east-west road runs ~3000 px perfectly horizontal, violating the straight-road ban (needs >=3 interior waypoints, +/-80-160px lateral offsets, 20-40 degree kinks). Its only 'variation' is abrupt half-width vertical steps where strips misalign and briefly overlap/double-thick (e.g. x~1240, 1650, 2280, 2590, and a stepped notch right at the east map edge ~3390) — these read as tiling bugs, not bends.
- fix: Repaint the road polyline with authored waypoints and gentle bends; fix segment joins so strips share one baseline.

### [whisper_passes] Road accent tiles form a visible checkerboard wallpaper
- where: entire road, e.g. clearly visible orig (455-1450, 1060-1160) and (2450-3420, 1060-1160)
- detail: Random darker-brown and red-brown squares are block-tiled INTO the road sheet, producing a Minecraft-like patch grid along the whole road — exactly the accent-in-tiled-sheet failure banned by bible rule 9 (accents must be scattered alpha decals, not tiles).
- fix: Flatten the road sheet to a uniform fill; re-add wear as sparse alpha 0.35-0.7 decals (~1 per 200k px^2).

### [whisper_passes] Spire tower planted on the road slab, occluding the route
- where: map center, orig px ~(2160-2230, 1090-1330); road passes behind cone at y~1090-1160
- detail: The second whisper-spire is placed directly at the road's south edge; its base kisses/overlaps the slab and its cone fully covers the road band, so the route visually dies behind the tower. Violates rule 5 (keep 60px clear of slab edges) and rule 6 (tall prop occluding the travel lane).
- fix: Move the spire >=60-100px south of the slab (or north of the road since it is tall), and bend the road slightly around it for a readable landmark beat.

### [whisper_passes] Ruined gate/tower facade pasted astride the road
- where: center-east, orig px ~(2455-2520, 1065-1165), directly on the road band
- detail: A flat ruined-castle facade (battlements + window holes) sits ON the road line: the road passes behind its crenellations and is completely hidden for its full width; no wall continues on either side so it reads as a 2D cutout dropped across the route, an unreadable crossing.
- fix: Either make it a real gate (arch the road THROUGH it, add wall stubs/rubble flanking) or shift it off-road as a ruin anchor with satellites.

### [whisper_passes] Zone identity failure — anonymous olive field
- where: map-wide; e.g. orig (1500-2600, 1300-2000) contains nothing identifying
- detail: Away from the two spires, any screenshot is a flat single-fill olive plain that could belong to any zone: no signature prop motif, no pass/ridge features implied by the zone name, no palette identity, and the ground sheet has effectively zero breakup texture. Fails bible rule 2.
- fix: Establish a signature motif (e.g. whisper-stones/cairns/wind-bent grass streaks), a distinct day-tint grade toward the anchor palette, and repeat it at breadcrumb intervals.

### [wilderness] Road does not pass through the gate arch — it runs behind the wall
- where: orig: arch ~(665-735, 1070-1125); slab band ~(760-1050, 1025-1100)
- detail: The slab road band starts at the wall's cut end and runs east at the height of the wall's battlements, i.e. NORTH of the arch line; the gateway itself opens onto plain grass with no path through it. The gate/road relationship is unreadable — the path visually clips out of the wall's sliced end.
- fix: Route the path through the arch opening and south around/along the wall; align path y with the gateway threshold.

### [wilderness] Path network is a city street-grid: razor-straight runs and perfect 90-degree corners
- where: zone center, rectangle orig ~(1740-2560, 700-1400); long straight vertical run ~(2740-2860, 560-1250)
- detail: The slab paths form a large closed rectangle around the central tree block plus long dead-straight N-S and E-W runs — zero interior waypoints, zero kinks. In a wild forest zone this violates the straight-road ban and reads generated.
- fix: Re-lay each polyline with 3+ waypoints, lateral offsets and kinks; let trees pinch the trail.

### [wilderness] Path material is a uniform square-slab grid (wallpaper repeat)
- where: all paths; clearest orig ~(760-1050, 1025-1100) and vertical run ~(2740-2860, 560-1250)
- detail: Every path is the identical square slab stamped in strict 3-wide columns with even grout gaps, like bathroom tiling; behind the gate it widens into multi-row slab bands with the same repeat. No size variation, no broken/missing-slab rhythm beyond a few gaps.
- fix: Introduce 2-3 slab size/shape variants, rotate/jitter placement, drop 15-25% of slabs with grass reclaim, and blend edges with tuft/pebble decals.

### [wilderness] East path dead-ends as a slab 'plaza' rectangle in open grass
- where: east side, slab rect orig ~(2950-3215, 865-950); grave+cobble blob overlap ~(3085-3185, 810-905)
- detail: The eastern run terminates in a ~4-row x 13-column rectangle of slabs with razor edges, stopping ~40px short of the map edge in bare grass — a road ending in open ground. On top of it, a dark cobble stain decal is slapped over both the slab grid and a gravestone's base with hard pixel edges, reading as a misplaced overlay.
- fix: Either continue the path to the map-edge gate or end it at an authored destination (shrine/camp); remove or re-anchor the cobble stain decal.

### [wilderness] Headstones placed on top of the walkway slabs at the coffin vignette
- where: NE area below the open coffin, orig ~(2750-2810, 490-565)
- detail: Two cross headstones sit directly ON the slab path tiles (not beside them), so graves block the middle of the walkway — a props-on-road collision per rule 5.
- fix: Shift the stones 30-60px off the slab run; let the path skirt the grave cluster.

### [wilderness] Carnival-striped canopies break the style anchor palette
- where: left camp orig ~(1200-1470, 875-980); SE camp orig ~(2465-2900, 1550-1850)
- detail: Both camps use bright saturated green/white, orange/white and red/white striped market canopies — the brightest, most saturated elements on screen, with 2-3 competing accent hues per composition (violates the one-accent law and the muted near-black gothic anchor; large pure-white areas are unearned highlights). Reads cheerful-fairground, not Raven Hollow.
- fix: Regrade canopies toward the anchor (desaturated leather/rust/bone stripes, weathered stains); reserve one accent hue per screen.

## MINOR
### [bloodroad] Same maroon table/bench sprite repeated as isolated singles along the road
- where: along road center; orig px ~(1944,861), (1890,1324), (1866,1417)
- detail: At least three copies of an identical maroon four-legged table prop are dropped alone within ~600px of each other beside the road (one nearly touching the slab edge), with no story context — confetti placement of a context-free prop.
- fix: Keep one, dress it into a cluster (stall/camp), delete or reskin the others.

### [bloodroad] Five identical gravestones in a rigid grid
- where: right-center; orig px (2155-2215, 1248-1297)
- detail: A 3+2 block of the exact same white gravestone sprite, grid-aligned with even spacing and zero jitter/scale/variant change. Violates the asymmetry law (rule 8) — bloodroad graves are organic, not the canon 'Finalized rows'.
- fix: Jitter positions +-8-16px, mix 2-3 stone variants, tilt one, add kneeling-worn ground decal.

### [bloodroad] Ruined tower reads as a rectangular tilesheet crop; cart overlaps its footprint
- where: top-center, west of road; structure orig px (1965-2013, 400-497), cart (1967-1990, 480-495)
- detail: The stone gate/tower fragment has perfectly sheared vertical edges and an unbroken rectangular silhouette (no broken crenellation, no rubble skirt at its base), reading like a cropped wall texture rather than a ruin. The red cart below overlaps into the wall's lower-left footprint.
- fix: Break the silhouette (missing top blocks, rubble/foundation decals at base), nudge the cart 20-30px south.

### [bloodroad] Ground grade reads dead grey, off the style anchor
- where: zone-wide
- detail: The entire ground sheet sits in a neutral grey-olive with no warm parchment floor, violating learned rule 23 ('no dead grey... warm every dark toward parchment'). Zone identity is weak: a random screen here reads 'grey field', not 'the Bloodroad'.
- fix: Warm the ground ramp toward the anchor neutrals (#453a31/#483a2f family) via the zone LUT; push red-soil signature decals along the road.

### [bloodstone_pit] Twin glowing graves mirrored about the pit, each with a detached halo
- where: orig px (1597-1620, 950-1005) and (2211-2235, 944-975); stray halos ~(1610,1050) and (2229,998)
- detail: Two near-identical open graves with glowing ember fill sit at mirrored positions left/right of the pit (same sprite, same y), and each casts a warm light pool centered ~100px SOUTH of the grave with no visible emitter at the halo's center — the floating-glow class of rule 12, plus symmetric duplication that kills the curiosity value.
- fix: Re-center each light on its grave, differentiate the two set-pieces (or keep one), give one a story satellite (dropped shovel, drag marks).

### [bloodstone_pit] Row of red pixels floating above an NPC reads as a debug HP bar
- where: orig px ~(1888-1900, 1036-1040)
- detail: A horizontal string of small red dots hovers above a skeletal figure south-west of the pit — it reads as a debug health bar or an unanchored blood decal caught in the shot.
- fix: If it is entity UI, exclude it from world screenshots; if a decal, anchor it to the ground under the figure.

### [canal_maze] Canal and road overrun the map bounds onto void
- where: orig px (1890-1970, 0-32) top, (1890-1970, 2125-2160) bottom, (3387-3400, 1085-1110) east
- detail: The canal's water and banks extend past the grass sheet into the grey void at both the top (~30px) and bottom (~35px) map edges, ending in razor mid-water cuts; the east road's last ~12px similarly overhang the map's east edge.
- fix: Clip painted layers to ground bounds, or extend the ground sheet under them to the true gate lines.

### [canal_maze] Four rowboats placed as a 2x2 grid of duplicate sprites
- where: in the canal at the junction; orig px (1887-1933, 1073-1120)
- detail: Two identical boat sprites side by side, duplicated again one row below — a neat grid of clones at the junction, violating the asymmetry law where a loose scatter with rotation/variants would sell a moorage.
- fix: Vary boat sprites/angles, offset spacing, tie to a dock once the crossing is built.

### [canal_maze] Unreadable square lattice prop dropped context-free near wolf pack
- where: orig px (2570-2620, 1140-1185)
- detail: A perfect square wooden lattice (11x11 uniform grid) sits alone on grass south of the road; it reads as a debug grid/pallet texture swatch rather than a garden bed or cage, and nothing around it explains it.
- fix: Replace with a readable prop (garden plot with soil+crops, or cage with broken bars tied to the wolf vignette).

### [canal_maze] Daylight grade is brighter/more saturated than the style anchor
- where: zone-wide
- detail: The zone sits in a fairly saturated olive-green with high overall luminance versus the anchor's near-black gothic grade (darks should dominate ~70%); next to bloodroad and the pit it reads like a different game's overworld.
- fix: Pull the day tint toward the anchor neutrals (desaturate ground, keep actors saturated per rule 23), deepen shadow mass under trees/buildings.

### [dead_timber] Village house wall kisses the ribbon bank edge
- where: village NW house, orig ≈(2215-2245, 755-870)
- detail: The tall timber house at the village entrance has its west wall touching the ribbon's bank edge pixels — inside the 60px road keep-clear. Reads as the house being built on the carriageway shoulder.
- fix: Nudge the house ~40-60px east.

### [dead_timber] Zone identity is thin — bright pasture undercuts the dead-timber fantasy
- where: zone-wide; most visible in the south half
- detail: The stump landmark, mushroom fields and dead-tree clumps exist but are sparse; most random screens are bright olive grass that could be any zone. The 'dead timber' read (clear-cut scatter, log piles, deadfall, grey-brown ground scarring) rarely dominates a screen, violating the one-screen zone-identity rule.
- fix: Add a clear-cut soil-scar ground layer under the stump/log clusters, raise the dead-tree density in the outer ring, and cool/grey the grass grade slightly toward the anchor.

### [drowned_quarter] Five identical headstones in a perfect evenly-spaced row on bare grass
- where: south-centre, orig ≈(1550-1655, 1655-1700)
- detail: Two headstone designs alternating in a dead-straight, evenly-spaced line with no graveyard dressing — no fence, soil mounds, ground change, or flowers. Even spacing reads as generated (asymmetry law); the queued LPC grave-marker variety pack would help.
- fix: Jitter positions/spacing, vary markers, add a dirt-patch decal, one leaning stone, and an out-of-line grave for story.

### [drowned_quarter] Floating string of white puffs with no emitter between village houses
- where: NW village cluster, orig ≈(1400-1435, 852-870)
- detail: A horizontal line of 5-6 small white dots (plus one orange) hangs in mid-air at wall height between two village houses — reads as a smoke/particle trail whose emitter (chimney) is nowhere near the trail's origin, i.e. the floating-glow defect class.
- fix: Re-anchor the smoke emitter to the chimney top, or delete the trail.

### [drowned_quarter] Village house roofs kiss (tangent ban) in NW cluster
- where: NW village cluster, orig ≈(1310-1365, 845-870)
- detail: The two western houses are stacked almost directly N-S; the front house's roof ridge kisses the back house's base along a long edge — the sprites neither overlap >25% nor separate >20px, producing the tangent read the slot grammar forbids.
- fix: Slide the front house ~40px S/SE so the overlap is deliberate or the gap honest.

### [drowned_quarter] Empty lattice pen floating alone in the NE void
- where: NE quadrant edge of vertical path, orig ≈(2000-2045, 575-620)
- detail: A small brown grid/pen sprite sits isolated on bare grass with nothing inside it and no context props within ~400px — an orphan single that highlights the surrounding emptiness.
- fix: Either dress it (animals, feed trough, mud) into a cluster or remove it.

### [lichenreach] Copy-pasted planter/grave-bed trio in a perfect row
- where: lower-right quarter; orig px (2171-2236, 1862-1908)
- detail: Three pixel-identical soil-bed frames with icy blue-white borders, evenly spaced in a razor row (middle one carries the same grey pot), isolated in empty ground with zero context. The exact same prefab (including the pot on the middle bed) recurs in morven_reach and near the listening_steppe hamlet — a legible cross-zone copy-paste signature. Frame color is also off the zone palette.
- fix: Jitter position/spacing, vary the sprites, ground them in a vignette (digger tools, spoil heaps), and recolor frames toward the neutrals ramp.

### [lichenreach] Ground macro-tile repeat visible as a grid
- where: zone-wide ground
- detail: The big-slab ground sheet tiles on a clearly visible grid at overview zoom — periodic dark blotch pattern repeats every macro-tile across the entire map. At gameplay zoom this will be subtler but the periodicity is strong.
- fix: Break the sheet with scattered decals (1 per ~200k px² per rule 9) and a couple of alternate macro-tiles.

### [lichenreach] Pale crate stack collision
- where: left-center; orig px (1533-1550, 515-560)
- detail: Three bright-white crate/box sprites stacked in an exact vertical column, overlapping each other, with a sack tangent to the side — reads as sprites dropped on the same point, and the pure-white palette pops oddly in a dread zone with no story context around it.
- fix: Fan the crates into an L-cluster with proper overlaps (>25% or >20px separation) and grade them toward parchment.

### [listening_steppe] Chapel anchor is naked and unconnected
- where: chapel at orig px (1536-1600, 510-600); hamlet at (2215-2385, 1683-1863)
- detail: The white chapel — the zone's most eye-catching building — floats in open grass with no approach path, no yard, no satellites, and no road spur (road is ~350px east). Same for the SE hamlet: three houses with no path linking them to the road and no breadcrumb props on the approach.
- fix: Add dirt spurs from the road, kneeling-worn ground, and 2-5 satellite props per rule 7 / rule 30.

### [listening_steppe] Same campfire+bedrolls prefab repeated three times
- where: orig px (1115-1195, 678-758), (2457-2555, 973-1048), (1258-1344, 1738-1786)
- detail: Three near-identical camps (fire + 2-4 red bedrolls) at NW, mid-east and SW — same composition each time, violating POI diversity rotation (rule 29).
- fix: Rework one into a ritual site and one into a wreck/abandoned camp (unlit hearth as a beat).

### [listening_steppe] Gravestone groups in razor-straight evenly-spaced rows
- where: orig px (1445-1545, 903-933), (2340-2410, 1348-1383), (1220-1270, 1088-1128)
- detail: At least three separate grave clusters are laid out as perfect rows with uniform spacing and no jitter, no ground wear, no fence or mound context (5-row mid-west, 4-row south-center, 3-row south-west). Asymmetry law reserves rows for meaning; these read generated.
- fix: Jitter position/scale, mix marker sprites, add worn-ground decals or a leaning marker.

### [morven_reach] Same copy-pasted planter-trio prefab as lichenreach
- where: right-center; orig px (2440-2490, 1400-1435)
- detail: Three identical grey-framed soil beds in a perfect evenly-spaced row (middle one with the same grey pot), floating mid-field with no context — byte-identical arrangement to the lichenreach and steppe instances; a visible generator signature once players see two zones.
- fix: Vary count/spacing/rotation per placement and tie each to a local vignette.

### [morven_reach] Orphaned context-free props by the south road
- where: center-south, flanking the vertical road
- detail: A flat square wooden lattice/grate panel lies alone on grass at (1835-1872, 1512-1548), and a frontal-view tool rack stands alone at (1990-2040, 1462-1530) — singles with no worksite, violating story-clusters-not-confetti (rule 4); the lattice square especially reads placeholder.
- fix: Fold both into one work-site cluster (sawhorse, timber pile, cart) or remove.

### [morven_reach] Four identical bright-white cross gravestones in a razor row
- where: lower-right quarter; orig px (2565-2645, 1765-1815)
- detail: Evenly spaced, same sprite, perfectly aligned, and their pure bone-white pops unearned against the olive field (anchor: highlights are rare and earned). The jittered small-stone cluster just south of them shows the right way.
- fix: Jitter spacing/scale, alternate sprites, knock the value down toward the neutrals ramp.

### [morven_reach] Confetti singles: naked cabins, chapel and glowing grave
- where: NW and NE quads, positions listed
- detail: Several lone buildings float in open grass with no yard, path, fence or satellites: cabins at (1171,432), (950,586), (1027,864), the white chapel at (2660-2710, 400-485), and an ember grave alone at (3005-3035, 370-410). Evenly sprinkled singles read generated; anchors demand satellites (rules 4/7).
- fix: Give each 2-5 satellites and a worn approach, or consolidate some into an existing cluster.

### [orange_fog] Emitter-less glowing graves (floating-glow class)
- where: native px ~(1436,834), (2574,666), (1850,1624), (2824,1586)
- detail: At least four graves emit a warm glow pool with no visible candle/lantern/flame sprite — rule 12's named defect class. Verified at 10x: plain headstone + dirt, glow only.
- fix: Add a small candle/lantern emitter sprite to each glowing grave or remove the light

### [orange_fog] Three identical framed graves in a razor-straight, evenly-spaced row
- where: right-center, native px ~(2865-2935, 845-915)
- detail: Three copies of the same grave sprite sit in a perfect horizontal row with equal gaps on bare grass, no context props (no fence, path, marker, tree). Mechanical placement that reads generated (rule 8 asymmetry law; rows are reserved for meaning and this one carries none).
- fix: Jitter positions/scale, add a story satellite (shovel, lantern, mourner prints) or fold into a proper burial vignette

### [riverfork] Market awning almost fully occluded behind shop roof
- where: village center, native px ~(2282-2313, 905-955)
- detail: A tall blue-white striped stall canopy is placed directly north of the big shop so only a striped band pokes out above the roofline — at play zoom it reads as a graphical glitch strip (rule 6: composition must not rely on y-sort).
- fix: Move the stall east/west of the building so the canopy reads whole

### [riverfork] Orphan cobblestone patch floating in grass
- where: village area, native px ~(2375-2405, 960-985)
- detail: An isolated rectangle of cobble/stone-wall texture sits alone in the field, connected to nothing — reads as a leftover floor fragment.
- fix: Extend into a deliberate paved yard/well base or remove

### [salt_fens] NPCs and props standing in the river channel
- where: along the river, lower third
- detail: Figure pairs stand mid-water with no boat/ford at ~(1215-1255, 1470-1495); a dead bush grows out of the channel at ~(2030-2050, 1500-1535); green bushes sit on the water at ~(770,1475) and ~(1300,1485). Collisions with the water body; likely missing water collision/keep-clear.
- fix: Add the river's keep-clear rect to spawners and nav-block the channel

### [salt_fens] Flat dark-green moss blobs read unfinished
- where: upper-center-left, native px ~(1245-1300, 615-670)
- detail: A cluster of flat, near-textureless dark-green rounded shapes (two small squares, a pill, a large rounded square) sits NW of the fire camp; interiors are flat fills with no linework, reading as unpainted decal masks.
- fix: Repaint with interior texture/highlights or swap for the standard moss/algae decal set

### [transcub_vale] Three identical open graves in a perfect row, undressed
- where: lower-center-right; orig px (2550-2620, 1740-1815)
- detail: Three copies of the open-grave asset sit evenly spaced in bare grass (middle one with headstone). Story potential (freshly dug graves) but zero dressing — no spoil mounds, shovel, cart tracks — and identical-sprite even spacing reads as a repeat.
- fix: Jitter spacing/rotation, add spoil heaps + shovel + footprint decals so it reads as a vignette, not a stamp.

### [vetka] Standalone bell tower: bright outlier, undressed base
- where: left-center; orig px (1258-1320, 812-945)
- detail: The parchment-white bell tower is the brightest object on the map (anchor palette says bone highlights are rare/earned) and stands alone — no church footprint, no path, no satellites, graveyard is 300px away.
- fix: Grade it 1-2 steps darker toward the neutrals ramp, add a worn-path decal and 2-3 satellites (bench, notice post, crows).

### [vetka] Indoor furniture prop stranded in open field
- where: center-right; orig px (2428-2452, 703-728)
- detail: A small dark-red bed/table with legs sits alone in grass near a single tombstone — an indoor sprite outdoors with no vignette around it.
- fix: Remove, or build the vignette (abandoned camp: bed + scattered belongings + trail decal).

### [vetka] Box props overlap the mill roof slope
- where: upper-right quarter, on the mill at orig px (2815-2870, 710-770)
- detail: Three birdhouse/crate-like boxes are pasted onto the mill's sloped roof plane at inconsistent heights with visible brackets — they read as separate sprites colliding with the roof rather than built dormers.
- fix: Move them to the walls/eaves line, or swap for proper dormer overlays baked into the building sprite.

### [vetka] Razor void borders; south road overshoots the map edge
- where: map edges; road overshoot at orig px (1905-1990, 2110-2160)
- detail: Map edges are unbrushed straight cuts to grey void; the south road additionally continues ~30px past the grass boundary and is drawn floating on the void.
- fix: Confirm camera clamps; trim road tiles to the world rect or hide behind a gate prop.

### [western_lowlands] Signpost with lantern planted inside the road surface
- where: center-left, at the crossing; orig px (1300-1325, 1100-1125)
- detail: The signpost + hanging lantern at the river crossing stands ON the road slab rather than at its shoulder (rule 5: 60px keep-clear).
- fix: Nudge it 30-60px north onto the verge; keep the lantern — emitter and glow are correct.

### [western_lowlands] Razor void borders; river overshoots the bottom edge
- where: map edges; overshoot at orig px (1225-1270, 2110-2160)
- detail: Map edges are straight cuts to void; the river band continues ~40px past the south grass boundary, drawn floating on the void.
- fix: Confirm camera clamps; clip the river to the world rect or run it under a border treatment.

### [whisper_passes] Road/grass edges are razor cuts with zero blending
- where: both road edges, full width, orig y~1058 and ~1160
- detail: The entire ~3000px of road has perfectly straight hard top/bottom edges — no tufts, pebbles or stains straddle the transition anywhere (bible rule 10 requires ~20-30% edge breakup).
- fix: Seam pass: scatter grass tufts, pebble and dirt-stain decals across the edge line.

### [whisper_passes] Evenly-spaced funerary rows repeated context-free (generated read)
- where: orig ~(1210-1310, 600-660); ~(2265-2350, 1555-1590); ~(2900-2965, 660-695)
- detail: Three separate spots use the same pattern: identical grave sprites in a perfectly even straight row floating in empty grass with no graveyard context (no fence, mounds, worn ground, or path): 3 open graves in a row; 5 headstones in a row; 4 headstones in a row near the hut. Violates asymmetry law rule 8/4.
- fix: Cluster them into one authored burial site with jittered spacing, dirt mounds, a worn path and 1-2 satellites; or scatter with position/scale jitter.

### [whisper_passes] Wolves spawned as copy-paste vertical pairs of one sprite
- where: S/SW quadrant, e.g. orig ~(1132, 1475), ~(1345, 1490), ~(1425-1500, 1830-1870), ~(2020-2050, 1855-1880)
- detail: Wolves appear repeatedly as two identical sprites in the same pose stacked almost directly one above the other (same x, ~30px apart), reading as duplicated stamps rather than a pack.
- fix: Vary facing/pose frames, jitter offsets, and stagger pack members diagonally.

### [whisper_passes] Huge sourceless dark blob decals repeated across the ground
- where: e.g. giant blob orig ~(2100-2700, 300-600); multiple across the N half and center
- detail: Soft-edged amorphous dark smudges (some ~600x300px) are stamped across the field at similar scale; presumably cloud shadows, but with no cloud motion cue in a still frame they read as dirty smudge decals and several repeat the same stamp shape.
- fix: If cloud shadows: animate drift and vary shapes/scales; if terrain stains: reduce size, tie to features (under trees/rocks).

### [whisper_passes] Double-stamped fire at the burial camp
- where: north-center camp, orig px ~(1756-1772, 590-635)
- detail: A campfire flame and a second burning-pile sprite overlap vertically at the same spot, reading as two fire assets accidentally stacked rather than one bonfire.
- fix: Keep one fire emitter; if a pyre is intended, use a single composed pyre asset.

### [wilderness] Wolves duplicated as stacked identical pairs at the coffin vignette
- where: orig ~(2632-2680, 515-575), ~(2727-2780, 410-462), ~(2845-2890, 490-545)
- detail: Six wolves are three copy-paste pairs of the same left-facing sprite, each pair stacked at the same x ~30px apart — reads stamped, not a pack.
- fix: Mix facings/poses, stagger diagonally, vary spacing.

### [wilderness] Recurring 'three red mushrooms in an even line' motif
- where: orig ~(1945-2035, 620-635); ~(1315-1405, 1060-1075); ~(1835-1925, 1570-1590)
- detail: The same red mushroom sprite appears as an evenly-spaced horizontal triple in at least three places (graveyard south, left camp, boar wallow) — an obvious generated pattern.
- fix: Cluster in irregular fairy-ring arcs or tuck singles against stumps/logs with scale jitter.

### [wilderness] Twisted-tree sprite reused at one scale with same-x stacked chains
- where: west edge column orig ~(600-650, 280-510); row of three orig ~(710-880, 850-940)
- detail: The single twisted-vine tree sprite repeats at identical scale throughout; in places it stacks in vertical same-x chains (4 in a column on the west edge) and same-y rows of three, creating local copy-paste reads in an otherwise well-filled forest.
- fix: Add 1-2 sprite variants or mirrored/scale-jittered instances; break chains by re-jittering positions.
