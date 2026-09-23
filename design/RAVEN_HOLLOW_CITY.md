# RAVEN HOLLOW CITY — the starting town grows into a walled border city

Owner decision (2026-09-13): Raven Hollow stays the starting town of EVERY class and is
expanded, Stormwind-style, into a walled city. The polished village (commits
9043e3c / 7018e6c / c98735d) is kept byte-identical as the first district; the city grows
around it on the same map (no loading screen between village and city).

**v2 — RE-PLAN + DENSIFY (owner choice 2026-09-21, Fable 5.1 driving).** The 09-13 skeleton
(S1) + districts (S2) were a right-angle grid of streets and two ruler-straight canals on a
flat lawn, houses in loose single rows, 600 px street pitch: at play zoom it read as
"buildings on a golf course" (audit shots `_screens/audit/city_*.png`). v2 keeps the
village, walls, keep, cathedral and river, throws away the grid, and rebuilds the interior
so it can be PACKED. Owner accepted the recommendation "re-plan and densify".

Canon note: WORLD_PLAN called Raven Hollow "a human border village". Owner retcon: it is
the fortified border town of the Long Vigil — the wall and the keep ARE the Vigil. Quest
text that says "village" stays true in spirit (the old Hollow is the village district).

## 1. Map
- 224x160 tiles (7168x5120 px). Walls: north face base y=136, south face base y=5080,
  west band x 40-104, east band x 7064-7128 (TownCity._outer_walls).
- The Hollow keeps its coordinates: (0..2240, 0..1600) = district 1. Every existing
  placement, NPC, quest anchor and the graveyard stay where they are. The village's random
  east/south tree bands are its hedgerows toward the city.
- **EAST GATE moved to the EAST wall** at y=2600 (gap in the band, flanked by square
  towers). Travel point MapRegistry.TOWN_EAST_GATE = (7000, 2600). The old brown gatehouse
  at (2192,846) stays as the inner Old Gate (no travel point).

**v3 — ALIGNMENT + BACK GARDENS (2026-09-21, after the owner's 2/10).** The Szadi module kit
has traps: `roof_gable_*.png` rows 0-7 are a stray ridge bar (crop from row 30); the ground
strip must be cropped centred on the DOOR (purple 142 / slate 128 / red 140) and cut to the
plaster band's width; chimneys sit ON the roof plane. Terraces BUTT (0 px), alleys every 5-8,
every house has a fenced back garden (veg rows / work yard / flower plot) planned before the
ground is painted. A 4th kind "shop" (windows row + flat roof) joins gable/cross/cottage.

**v4 — LIFE + VARIETY (2026-09-21, after the owner's 3/10).** `scripts/town_life.gd` (TownLife)
places 76 named city folk with two-line voices at the places that explain them (vendors behind
stalls, guards at gates, pilgrims at the statue, gardeners in the allotments, dock hands on the
quay). Facades: 40% mirrored (per-sprite flips), per-house tint, wall lamps, shop awnings, ivy.
Ground: civic squares in pale flags, worn holes in the cobble. Motion: animated fountain, torches,
fire pits. Fills: keep courtyard, cathedral forecourt, the Hospice of the Vigil, the east quay.

**v5 — GROUND, CANOPY, FARMLAND, SOUTH BANK (2026-09-21).** Tonal blobs over the whole city
ground; every leafy tree on the GPU sway shader; trees in gardens, on squares and quays,
copses on the commons, willows on the river; three chimney variants and a cast shadow per
house; four story vignettes; fenced field lanes, haystacks, a sheepfold, a wayside cross;
the towpath, reeds, the ferryman's yard and the eel-smokers along the river. 90 city folk.

**v6 — FULL HOUSES (2026-09-21, owner).** The module assembly is retired. Every city house is
one of the eight Szadi Fantasy Lands full houses (buildings/house_00-07) the village uses:
cottage/gable/cross/shop/work/barn/shed/inn. Terraces keep a 10-26 px seam for the baked
yards, no adjacent repeats, 40% mirrored, per-house tint. More variety needs more full-house
art in this exact style (verified free) — an owner decision.

**v7 — THE 4/10 PASS (2026-09-22, owner: "does this look like a triple-A pixel game? improve
the level, this is a 4/10").** Five ordered passes from a three-lens critique (ground / light /
repetition) plus three sheet probes. GROUND: the city's cobble/flag overlay is split off the
village overlay onto its own TileMapLayer with a warm-grey stone tint (the village keeps
GROUND_TINT byte-identical); a soft neutral wash sits under the overlay over every packed-earth
area so the terraces stop reading orange; street wear is decals + cart ruts (the hub-punched
"worn patches" are gone); packed earth under every terrace; cobble 46 / shoulder 64; sprig tiles
swapped for clean cobble fills; Old Town streets get a coped stone wall composited from the
Cainos wall sheet, the ward gets the craft quarter's rail fence; weeds stay off the carriageway.
GROUNDING: contact shadow under every free-standing prop, sill + east-wall shadows per house,
lanterns show grey glass by day and burn from 17:00 with a flicker (scripts/city_ambience.gd).
VARIETY: one tree helper (kind / scale / flip / four muted tints / canopy shadow), wider house
tints + 15% weathered, Szadi building-parts attachments (dormers, ridge caps, chimneys, the
shop's missing door, a wooden chimney on the barn so its smoke leaves a chimney), a NINTH
silhouette (narrow half-timbered townhouse composited from the parts sheet), doorstep clutter
owned by every door, washing lines across alleys, two-crop gardens with a sprout row and corn
back rows, denser commons and churchyard meadows. MATERIAL/LIGHT: green mottling on the lawns,
a paved apron under the Trade Square fountain, cypress planters, a water skin on canal/river/
basin (cool wash, shader-scrolled highlight that FLOWS, glint, bank shade, drifting flecks),
rooks crossing the sky. Not achievable without new art: more than nine building silhouettes,
more than three leafy canopies, fauna, N-S low walls (the Cainos sheet has no vertical face).

**v8 — THE FIVE-LENS PASS (2026-09-23).** Five independent critics (ground, light, repetition,
composition, AAA benchmark) rated the v7 level 4-5/10 and named the tells; the driver verified
every finding against the frames and the sheets, then fixed them in four passes. GROUND: the
city paving is drawn from a DE-BLADED copy of the keyed sheet (no more grass lip sprouting out of
packed earth), the plazas sit on their own mid-grey layer, city earth is desaturated on its own
layer, and a second accent overlay gives the quay, keep court and fountain ring brown setts —
three paved materials. LIGHT: lit windows and a lantern bloom with real pools make night read as
night; torches and braziers obey the clock (iron sconces by day); plumes of smoke; vendors are no
longer black cut-outs; everything casts a contact shadow and house shadows sit on the brick line.
VARIETY: fields and gardens have growth stages, fallow strips and staggered rows; walls, lamps,
bushes, stalls and doorstep clutter all vary per instance; no house kind repeats within three
slots; hanging trade signs and a well/shrine/board on every other lamp gap give each terrace
screen a destination. COMPOSITION: the keep towers with two round drums, the harbour gets a
waterline, railings, a watch tower and its anchor, and the Trade Square's north frontage is
paved. Still open: the diagonal roads are 32 px staircases (a textured ribbon per road is the
fix), dusk keeps noon shadows, the ward square has no north facade.

## 2. Layout law (from the Painting Bible)
- No ruler roads: every street is a polyline with lateral drift; the canal winds.
- Rows are shoulder-to-shoulder (2-14 px gaps) with an alley every 3-5 houses; fronts on
  the NORTH side of every east-west street (the sprites face south), garden walls/hedges
  + yard bits on the SOUTH side; street pitch 440 px so back gardens are ~70 px deep.
- Ground under every district is DIRT (base layer), cobble streets/squares on the keyed
  overlay. Grass survives only in gardens, commons, fields and the wildwood strip.
- Fields/orchards/commons are painted as places with anchors every <=1500 px (40-s rule),
  not as lawn.

## 3. Districts (world px)
| # | District | Where | Character |
|---|----------|-------|-----------|
| 1 | The Hollow | 0-2240 x 0-1600 | untouched village. Start point. |
| 2 | The Approach + Old Gate | 2240-3000 x 700-1150 | cobbled main street winding SE from the old gatehouse to the Trade Square; toll house, trough, signpost. |
| 3 | The Burned Garrison | 2300-2700 x 260-640 | WARRIOR pocket (canon: "the Emberfall razed the old garrison, only the drill-yard survived"): scorched wall stubs, trampled drill floor, dummies, racks — curiosity site. |
| 4 | The Horse Fair | 2350-2900 x 1180-1480 | dirt oval, paddock fences, troughs, hay, carts, the Gate Tankard tavern at its east end. |
| 5 | The Vigil Keep | 2800-4400 x 136-660 | as S1 (compound, gate at (3600,660), keep block) + barracks row, stable, well, drill patch. |
| 6 | Trade Square | centre (3300,1080), ~800x480 | ringed by houses: bank (W of the keep road), auction house (E), shops; market stalls south; the canal BASIN and quay along its south edge. |
| 7 | Cathedral Square | centre (5400,1020) | cathedral at (5400,620), statue of the Vigil, almshouse/chapter rows W and E, churchyard NE, the leat along its south. |
| 8 | The Candle-House | (6620,860) | MAGE pocket: council-sealed cottage in a hedged plot east of the churchyard, one candle lit. |
| 9 | Old Town | 2300-4200 x 1600-4200 | five curved E-W streets (y~1980/2420/2860/3300/3740) + the N-S spine from the basin to the harbor; well square at the spine x S2, tavern square (rogue's fog-alleys) at the spine x S4. |
| 10 | The Canal | river (4160,4560) -> basin (3300,1540); leat basin -> east wall | winding; bridges at every street crossing. |
| 11 | East Ward | 4480-6900 x 1700-4200 | the EAST ROAD (Old Town S2 -> ward square (5420,2640) -> east gate) with the craft quarter (tanner, potter, carpenter, cooper) + three curved E-W streets (y~3040/3480/3920); the cathedral avenue runs N-S through it over a leat bridge. |
| 12 | Harbor | 2600-4700 x 4180-4560 + river | warehouses, quay square (3080,4300), piers, boats, cargo; water gate. |
| 13 | The Fields | 0-2300 x 1650-4500 | two farmsteads, four tilled fields, orchards, paddock, pond, granary tower, the mill by the river; hedged lanes; the Ashen Chapel ruin (PALADIN pocket) on a mound at (520,2000); wildwood strip along the west wall (DRUID nod). |
| 14 | SE Commons | 6300-6900 x 3200-4300 | track from the east road; burned farmstead (crime scene), fishermen's shacks, the justice corner (gallows + stocks) near the gate. |

## 4. Build stages (each ends with a boot, screenshots LOOKED AT, RH_PROPAUDIT, BACKLOG note)
- R1 GROUND + SKELETON: paint_masks v2 (curved streets, canal + basin + leat, fields,
  dirt districts), walls with the east-wall gate, canal colliders + bridges, house rows on
  every street with south-side hedges/yards, squares, harbor, fields v1. Whole city in one
  4K shot; walkable end to end.
- R2 DRESSING: street furniture, alleys, yard clusters, market, craft yards, harbor cargo,
  keep courtyard, cathedral square, class pockets (garrison, candle-house, chapel ruin).
- R3 LIFE + LIGHT: cast anchors at doorsteps, guards, lamps at night, chimney smoke,
  curiosity sites x2 + crime scene x1 per district, minimap texture, 40-s check, sweep.
- R4 SYSTEMS: bank/auction/trainers/vendors inside their buildings, quest anchors,
  waystation, wilderness gate travel point verified both ways.

## 5. Kit (verified free; on disk)
- assets/art/world/houses (Szadi Houses Pack modules, 3 colourways), buildings/house_00-07
  (Szadi Fantasy Lands demo), world/castle (LPC castle mega pack dark), world/street (LPC
  Victorian town decorations), world/freekit, world/coast, props (Szadi/Cainos),
  vegetation, terrain (LPC Terrains v7 via TerrainPainter).
- Missing locally (re-download from OGA, licenses in CREDITS_WILD.txt / MASS_DOWNLOAD):
  LPC farm animals, cats/dogs, birds; the wilderness fauna sheets (Steam blocker).

## 6. Engineering
- `scripts/town_city.gd` (TownCity, static) rewritten as v2; same two entry points
  (paint_masks, build) called from TownBuilder; polylines are the single source of truth
  for streets, canal and rows.
- MapRegistry.TOWN_EAST_GATE -> (7000,2600). GateBuilder still draws the inner Old Gate
  with paint_road=false. Backups of the 09-13 scripts: session scratchpad/backup_2026-09-21.
- No git on the PIT machine: keep before/after screenshots in _screens/audit and the
  change log in BACKLOG #129.
