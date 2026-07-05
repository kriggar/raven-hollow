# BLUEPRINT #99 + #52 — COLLISION AUDIT + FREEDOM PHYSICS
Fable design, Opus executes. Canon: FREEDOM_PHYSICS.md + owner mandates
(#99 footprint-true collision; #52 GTA freedom / Zelda physics props).

## The prop taxonomy (the audit table — LAW)
Every landmark/prop class gets exactly one of:
- NONE (walk-through dressing): decals, stains, tufts, ivy, bones piles,
  boot-prints, chalk, thread lines, ledger tablets (small), waterline
  stains, chimney smoke, ALL vignette dressing, lichen patches, gift-field
  soil, salt-pan surface (it's a floor), ground breakup, road edge decals.
- STATIC-FOOT (StaticBody2D on the FEET-LINE ONLY, never sprite rect):
  buildings (collision = bottom 30% of sprite width×~26px strip at base),
  trees (trunk circle r=7 at base; canopy NEVER collides), wells r=16,
  statues/monoliths/dolmens (base ellipse), stalls (bench rects; canopy
  pass-under), lamps/posts r=4, rocks/cairns (ellipse 0.8×base), fences
  (thin strip per post row), piers (SOLID FLOOR over water: pier deck is
  walkable — add water NONE-walk zone around it), boats moored (hull
  ellipse), wrecks (hull), vents (mound ellipse), pit (RING collider:
  Area2D inner = fall/damage zone v2, static ring lip r_out/r_in), sea
  band (full-band StaticBody wall 40px inside the water edge).
- PUSHABLE (RigidBody2D, Zelda-feel — #52): crates/cargo, barrels, small
  logs, buckets. mass 8-20, linear_damp 6 (stops fast), lock rotation,
  collision layer separate so enemies don't shove them around all night.
  Cap per zone: ≤ 30 live rigid bodies (perf); beyond that spawn STATIC.
- SPECIAL: graves = STATIC low rect per stone (walk between rows!);
  campfire = STATIC r=10 + Area2D damage-tick v2; river/canals = STATIC
  banks with gap only at plank_walk/bridges; ice ponds = NONE (walkable,
  v2 slide modifier).

## Implementation (zone_builder.gd — one helper, called per placement)
static func _foot_collider(parent, pos, kind, w:=0.0, h:=0.0):
  match kind: "strip" → StaticBody2D+RectangleShape at pos (w×h);
  "circle" r → CircleShape; "ring" (r_out, r_in) → 12-segment polygon ring.
Wire into: _sprite (buildings auto-detect via path contains "/buildings/"
→ strip 0.62*tex_w × 26 at base), landmark branches per taxonomy above,
scatter (trees→trunk circle; rocky boulders→ellipse), pier/boat/wreck
branches, sea band, river builder (banks along polyline: segmented
RectangleShapes every 64px, gap where plank_walk overlaps).
PLAYER: CharacterBody2D already collides with world (verify mask). ENEMIES:
same mask BUT navigation - see pothole.

## POTHOLES (from production)
- Y-SORT vs collider: colliders are children of the same y-sorted parents —
  collision is position-based, unaffected. Fine.
- Navmesh/pathing: enemies steer, not navmesh — adding colliders can trap
  packs. Mitigate: keep foot colliders MINIMAL (feet-line law) + enemy
  steering already has separation; add simple wall-slide (move_and_slide
  handles it). Full navmesh is #76's job, not this one.
- The 40 zones already shipped WITHOUT most colliders — this is a pure
  additive pass; keep_clear data means props rarely block roads anyway.
- Perf: thousands of static bodies is fine in Godot 4 (broadphase), but
  create shapes SHARED (one RectangleShape2D resource per size class).
- Doors: buildings have no interiors yet — collider strip must leave the
  door arch walkable? NO — v1 buildings are solid; interiors are future.

## Validator (tests/qa.py layer — per QA_AUTOMATION)
tools/collision_probe.py: boots each zone (RH hook RH_PROBE=collision),
walks a grid bot INTO each landmark from 8 directions, asserts: (a) cannot
stand inside building sprite base, (b) CAN walk through decal classes,
(c) CAN pass under stall canopy row, (d) cannot enter sea/river except at
piers/planks. Emits per-zone pass/fail JSON.

## Build order
1. _foot_collider helper + buildings + trees (biggest feel win).
2. Water: sea band + river banks + pier walkways. 3. Monuments/rocks/etc.
4. PUSHABLE crates/barrels (the Zelda moment) + cap. 5. Probe validator +
   full 40-zone run. Acceptance: probe green ×40, no enemy pack perma-stuck
   (watch 3 min/zone via probe), pushing a crate feels weighty (video).
Effort: 2 Opus sessions.
