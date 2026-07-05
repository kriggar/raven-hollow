# BLUEPRINT #98 — SEAMLESS WORLD (no loading screens)
Fable architecture, Opus executes. Read with CLAUDE.md potholes in hand.

## Goal
Walking across any border seam feels continuous: no fade-to-black, no spawn
teleport. Fast travel and ferry KEEP the fade (they are jumps; that's fine).

## Strategy: NEIGHBOR PRE-BUILD + WORLD OFFSET (not one mega-map)
Zones stay separate Node2D worlds (memory + y-sort + culling stay sane).
When the player nears a seam, the neighbor zone is built OFFSET so its gap
aligns with ours; the player walks across; ownership flips; the old zone
unloads behind. The camera never cuts.

## Data (zone_defs.gd — additive, no format break)
Each travel_point on a border seam gains:
  "seam": {"edge": "east", "offset_alignment": true}
(interior points — cellar stairs, ferry — omit "seam": they keep change_map.)
Derive the neighbor's world offset from the two paired gap rects:
  offset = my_gap_world_pos - their_gap_world_pos  (compute once, cache)
For an east seam: neighbor_origin.x = my_width_px - 0 (flush), y aligned by
gap centers. Write a static ZoneDefs.seam_offset(a_id, point_id) -> Vector2.

## Engine changes (all in main.gd + one new autoload)
NEW: scripts/zone_streamer.gd (autoload ZoneStreamer)
  - state: {current_id, neighbor_id, neighbor_root: Node2D, neighbor_offset}
  - PRELOAD_DISTANCE := 1200.0  # px from seam point
  - COMMIT_LINE: the gap rect edge itself
  - API: tick(player_pos) called from main._physics_process

### tick() algorithm
1. If player within PRELOAD_DISTANCE of any seam travel_point with "seam":
   a. if neighbor not built: _build_neighbor(to_map, offset) ASYNC (below).
2. If player crosses the zone boundary line inside the gap rect:
   a. FLIP: current world root and neighbor swap roles.
   b. Reparent nothing — instead move BOTH roots by -offset so the new zone
      sits at origin (one frame, imperceptible: also shift player, camera,
      and camera limits by -offset in the same frame — Godot handles this
      atomically before render if done in _physics_process).
   c. main.current_map_id = new id; fire the existing hooks: music/ambience
      switch (crossfade 2s, NOT hard swap), weather.on_map_changed (KEEP
      blend 0 precip purge only when biome family changes), minimap/banner,
      autosave, DayNight biome flags (underground/ambient_bias/lock).
   d. Queue_free the old zone AFTER the player is 800px past the seam
      (hysteresis prevents thrash at the line).
3. If player walks away (>1600px), free the pre-built neighbor.

### _build_neighbor(id, offset) — async, no hitch
Godot 4 has no thread-safe scene-tree build; do TIME-SLICED build instead:
split ZoneBuilder.build_zone into staged coroutine:
  build_zone_staged(parent, def, budget_ms=4) with `await get_tree().process_frame`
  between stages: ground → sea/river → roads → breakup → scatter (chunked
  500 sprites/frame) → landmarks (chunked 10/frame) → vignettes → border.
Root node: Node2D positioned at `offset`, added under a "Streaming" sibling
of World. THE BUILDER ALREADY takes `parent` — pass the offset root; zero
builder math changes (positions stay zone-local).
POTHOLE: TileMapLayer roads use zone-local cells — the offset root handles
world placement; do NOT translate cells.
POTHOLE: enemy spawns — spawn neighbor enemies ONLY on flip (they're
CharacterBody2D physics; pre-spawning doubles physics cost). Store
enemy_spawns in the streamer state, spawn on commit.
POTHOLE: WeatherSystem is screen-space — nothing to do at seams; ambience
crossfade needs a second AudioStreamPlayer (add _zone_ambience_b, tween).
POTHOLE: TravelSystem.register_station fires during neighbor build →
guard: skip discovery banners for non-current zones (flag in streamer).
POTHOLE: camera limits — currently set per-zone bounds; during transit set
limits to the UNION of both zones' rects (shifted), restore after flip.
POTHOLE: culling (#perf) — the visibility culling loop must include the
neighbor root's children (it iterates World only today: extend to Streaming).

### Player collision at borders
Border walls block gaps already; the gap rects are open. Ensure border wall
of ACTIVE zone near the seam doesn't overlap the neighbor's walkway: walls
already respect gaps — verified in Batches A-G. Nothing to do.

## Save/Load
current_map_id + player pos already saved. If saved mid-transit (within gap
hysteresis), snap to the zone that owns player_pos; streamer state is NOT
persisted (rebuilds on approach). Add save guard: block autosave during the
flip frame.

## Build order for Opus (each step boots + screenshots before next)
1. ZoneStreamer autoload skeleton + seam metadata + seam_offset() (no build).
2. build_zone_staged refactor (pure mechanical: insert awaits + chunking)
   — verify: boot every zone via RH_MAP, compare screenshots to pre-refactor
   (pixel-diff tolerance for rng-order: seed rng identically per stage;
   simplest: keep ONE rng, chunk WITHOUT reordering calls — chunking must
   not change call order or all scatter moves).
3. Streamer pre-build path (neighbor visible across the seam!) — screenshot:
   stand at stonepath/whisper seam, the Whisper Passes visible beyond.
4. Flip + reparent-shift + hooks. Test: walk vetka→copper_wells→stonepath
   →whisper_passes→ridges→blestem without a single fade.
5. Enemy spawn-on-commit + unload hysteresis + save guard.
6. Full 40-zone walk test via scripted RH_WALK hook (add: auto-walk player
   along a coordinate list, screenshot each seam).
Acceptance: zero fades on all 34 land seams; memory stays < 2 zones + town;
no 40s-rule regressions; travel/ferry/cellar still fade correctly.

## Effort estimate
Opus: 2-3 sessions. Riskiest piece: staged-build rng order (step 2 gate
catches it). Fable pre-designed everything else away.
