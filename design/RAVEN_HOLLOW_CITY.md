# RAVEN HOLLOW CITY — the starting town grows into a walled border city (Fable, 2026-09-13)

Owner decision (2026-09-13): Raven Hollow stays the starting town of EVERY class and is
expanded, Stormwind-style, into a massive walled city. The polished village (commits
9043e3c / 7018e6c / c98735d) is kept byte-identical as the first district; the city grows
around it on the same map (no loading screen between village and city).

Canon note: WORLD_PLAN called Raven Hollow "a human border village". Owner retcon: it is
the fortified border town of the Long Vigil — the wall and the keep ARE the Vigil. Quest
text that says "village" stays true in spirit (the old Hollow is the village district).

## 1. Map
- Old map: 70x50 tiles (2240x1600). New map: **224x160 tiles (7168x5120 px)**, same size
  class as the mid zones (validators, camera, nav all proven at this size).
- The old village keeps its coordinates: (0..2240, 0..1600) = **the Hollow** (district 1).
  Every existing placement, NPC, quest anchor and the graveyard stay where they are.
- Map edges: forest ring only on the west and north edges of the Hollow; everywhere else
  the CITY WALL is the edge of the playable world (inset 200 px from the map edge).

## 2. Districts (world px)
| # | District | Rect | Character |
|---|----------|------|-----------|
| 1 | The Hollow (existing village) | 0-2240 x 0-1600 | mud lanes, thatch, plaza, inn, smithy, graveyard, farm. Start point. |
| 2 | Old Gate + Trade Square | 2300-4300 x 300-1900 | the village's old gatehouse (2192,816) becomes an inner arch; beyond it the great cobbled square (center 3300,1000, ~800x520) with the fountain-statue, 8 market stalls in two rows on the south side, bank + auction house + 4 shop fronts around the square, lamp posts, planters, benches. |
| 3 | Cathedral Square | 4500-6300 x 200-1500 | cathedral facing south onto a paved square (statue of the Vigil), churchyard east of it, chapter house, bell tower, hedged gardens. |
| 4 | The Vigil Keep | 2800-4400 x 0-320 (north wall) | the garrison keep built INTO the north wall above the Trade Square: gatehouse, two towers, courtyard, banners, guards. Overlooks the square. |
| 5 | Canal District | canal ring (see 3) | stone-banked canals with 6 bridges; canal-side rowhouses, a boat landing, a lock. |
| 6 | Old Town | 2300-4300 x 2400-4200 | dense timber rowhouses (Szadi modules) along three curved cobble streets, two small squares (well, tavern), alleys, washing lines, cats and dogs. |
| 7 | Harbor | 2600-4600 x 4200-4500 (inside the south wall) + river outside | river along the south edge (y 4600-4900); the harbor quarter with piers, warehouses, crane, boats, a water gate in the south wall. |
| 8 | The Fields | 0-2240 x 1700-4300 | outside the inner village fence, inside the outer wall: fields, orchards, paddocks with animals, the windmill on the rise (1100,3000), two farmsteads, the mill by the river. |
| 9 | East Ward + East Gate | 4500-6900 x 1700-4300 | craft quarter (tannery, carpenter, potter), a second inn, the great EAST GATE (6968, 2600) to the Emberfall Road (wilderness), guard post, stables. |

## 3. Water
- River: y 4600-4900, full width, Water + Shallows (painter), stone quay in the harbor.
- Canal A (east-west): y 2100-2220, x 2300-6400 — separates the squares from Old Town.
- Canal B (north-south): x 4300-4420, y 300-4600 — separates Trade from Cathedral/East.
- Banks: castle-kit wall strips (stone) along every canal edge; bridges (stone, LPC) at
  every street crossing: (3300,2160) (4360,1000) (4360,2160) (4360,3200) (5400,2160) (3300,4300).

## 4. Walls and gates
- Outer wall ring (200,200)-(6968,4480): castle_keep_wall strips + towers every ~640 px +
  corner towers; gatehouses: EAST (6968,2600) → wilderness; SOUTH water gate (3600,4480) →
  harbor/river; the keep gate in the north wall (3600,320) → keep courtyard.
- The old village gatehouse stays as the inner "Old Gate" between the Hollow and Trade.

## 5. Streets (painter bands, cobble = Mudstone_Gray overlay; lanes = Dirt_Roots)
- Main street: Old Gate (2240,816) → Trade Square (3300,1000) → bridge (4360,1000) →
  Cathedral Square (5400,900) → east avenue → East Gate (6968,2600).
- South avenue: Trade Square → bridge (3300,2160) → Old Town spine → harbor gate (3600,4480).
- Field lanes: dirt, from the Hollow's south road to the windmill and the mill.

## 6. Kit (verified free; see scout manifest _downloads/scout_2026_09 + mass_2026_07)
- Buildings: Szadi Houses Pack modules (walls/roofs/shop fronts) for rowhouses; Szadi
  Fantasy Lands demo houses (8) for detached houses; LPC Victorian buildings (brick
  townhouses, if the style gate passes); castle mega pack (walls, towers, gatehouse, keep);
  Diednight / LPC church for the cathedral; windmill (scout).
- Ground: LPC Terrains (painter) — cobble, stone, water, shallows, soil, dirt.
- Life: LPC farm animals, cats & dogs, birds (32px, same family as the fauna already used).
- Dressing: Szadi props, Cainos stone, LPC decorations, LPC flowers/hedges/planters (scout).

## 7. Build stages (each ends with sweep + RH_PROPAUDIT + sitting + commit)
- S1 SKELETON: map 224x160; walls + gates + towers; canals + banks + bridges; river +
  harbor quay; street and plaza ground; camera/nav/minimap/travel points updated. Village
  untouched. Deliverable: the whole city readable in one 4K shot, walkable end to end.
- S2 DISTRICTS: Trade Square (fountain, market, bank, shops), Cathedral Square, Keep,
  Old Town rowhouse generator (module-based, seeded, y-sorted), Harbor, East Ward, Fields
  (windmill, mill, farmsteads, orchards).
- S3 LIFE + POLISH: NPC cast anchors for every doorstep (NPCCastSystem), guards, animals,
  banners, chimney smoke, lamps at night, hedges/flower beds/planters, curiosity sites and
  one crime scene per district (Bible V), 40-second rule, sitting, Steam-shot test.
- S4 SYSTEMS: bank/auction/trainers/vendors moved into their buildings, quest anchors for
  the city NPCs, waystation, the wilderness gate travel point moved to (6968,2600).

## 8. Engineering
- New script `scripts/town_city.gd` (class_name TownCity, static): wall ring, gate
  composites (GateBuilder generalised), canal + bank + bridge, rowhouse generator,
  plaza/street masks (into the TownBuilder painter canvas), district dressers, anchors.
  TownBuilder.build() calls TownCity.build(...) after the village pass.
- Size consts: TownBuilder.WORLD_TILES_W/H → 224/160; vegetation bands and border forest
  restricted to the Hollow's west/north edges; world border collider = outer wall.
- GateBuilder.GATE_POS / MapRegistry.TOWN_EAST_GATE → (6968,2600 + offsets); the old
  gatehouse re-added as a decorative inner arch (paint_road=false, no travel point).
- Minimap: assets/art/maps/town.png regenerated from a 4K overview; map_system town marker.
- Performance guard: TileMapLayers for ground; rowhouse modules as Sprite2D (≈3-5k props
  total); RH_PROPAUDIT extended with a per-district count.
