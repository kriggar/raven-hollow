extends Node
## NavSystem (autoload) — runtime navmesh pathfinding for enemies + wandering NPCs
## (the in-lane, pure-GDScript sliver of BACKLOG #96: "bots with perfect navmesh").
##
## The zones are built PROCEDURALLY in code (zone_builder places StaticBody2D
## footprint colliders at runtime, BLUEPRINT_99), so there is no authored, pre-baked
## navmesh. This system bakes one AFTER each zone builds: it takes the walkable
## bounds and carves every static collider's rectangle out of it, producing a
## NavigationPolygon on a single NavigationRegion2D. Enemies + NPCs then query
## NavigationServer2D.map_get_path() to route AROUND obstacles instead of grinding
## head-on into walls.
##
## Fully guarded + additive: if a bake fails or nav is not ready, callers fall back
## to their existing direct steering (behaviour identical to before). Gated by
## `enabled` — RH_NONAV=1 forces it off for A/B testing combat feel.
##
## API:
##   bake_for(bounds: Rect2, world: Node2D)   build the navmesh for the current zone
##   clear()                                   drop the current navmesh (on map change)
##   next_point(from: Vector2, to: Vector2) -> Vector2
##       the next waypoint on the path from->to (returns `to` when nav is off/unready,
##       so callers steer straight — the safe fallback).
##   is_ready() -> bool

var enabled: bool = true

const AGENT_RADIUS := 10.0     # inflate obstacles so bodies don't clip corners
const CELL_SIZE := 8.0

var _region: NavigationRegion2D = null
var _map_rid: RID = RID()
var _baked: bool = false


func _ready() -> void:
	enabled = OS.get_environment("RH_NONAV").is_empty()


func is_ready() -> bool:
	return enabled and _baked and _map_rid.is_valid()


## Build a navmesh for `bounds` (the walkable world rect) by subtracting every
## static collider under `world` from it. Attaches a NavigationRegion2D to `world`
## so it is freed with the zone. Safe to call once per zone build.
func bake_for(bounds: Rect2, world: Node2D) -> void:
	clear()
	if not enabled or world == null or not is_instance_valid(world):
		return
	if bounds.size.x < 32.0 or bounds.size.y < 32.0:
		return

	# 1. Outer walkable boundary (the whole zone rect, slightly inset).
	var outline := PackedVector2Array([
		bounds.position + Vector2(AGENT_RADIUS, AGENT_RADIUS),
		Vector2(bounds.end.x - AGENT_RADIUS, bounds.position.y + AGENT_RADIUS),
		bounds.end - Vector2(AGENT_RADIUS, AGENT_RADIUS),
		Vector2(bounds.position.x + AGENT_RADIUS, bounds.end.y - AGENT_RADIUS),
	])

	var poly := NavigationPolygon.new()
	poly.agent_radius = AGENT_RADIUS
	poly.cell_size = CELL_SIZE
	# The outer walkable boundary as the base traversable area.
	poly.add_outline(outline)

	# Feed every static collider to the RASTERIZATION baker as obstruction
	# geometry. Unlike make_polygons_from_outlines() (which crashes the convex
	# partitioner on overlapping/degenerate hole outlines), bake_from_source_
	# geometry_data() voxelizes at cell_size and is immune to overlap degeneracy —
	# the correct tool for dozens of procedurally-placed footprints.
	var src := NavigationMeshSourceGeometryData2D.new()
	src.set_traversable_outlines([outline])
	var bound_rect: Rect2 = Rect2(outline[0], outline[2] - outline[0])
	var holes: int = 0
	for body: Node in world.find_children("*", "StaticBody2D", true, false):
		var rect: Rect2 = _body_world_rect(body as StaticBody2D)
		if rect.size.x <= 0.0 or rect.size.y <= 0.0:
			continue
		rect = rect.intersection(bound_rect)
		if rect.size.x <= 2.0 or rect.size.y <= 2.0:
			continue
		src.add_obstruction_outline(PackedVector2Array([
			rect.position, Vector2(rect.end.x, rect.position.y),
			rect.end, Vector2(rect.position.x, rect.end.y)]))
		holes += 1

	NavigationServer2D.bake_from_source_geometry_data(poly, src)
	if poly.get_polygon_count() == 0:
		# Baker produced nothing (shouldn't happen) -> fall back to the open
		# boundary so pathing still works in a straight line.
		poly.clear()
		poly.add_outline(outline)
		poly.make_polygons_from_outlines()

	# 4. Region on a fresh navigation map so it is fully isolated per zone.
	_region = NavigationRegion2D.new()
	_region.name = "NavRegion"
	_map_rid = NavigationServer2D.map_create()
	NavigationServer2D.map_set_active(_map_rid, true)
	NavigationServer2D.map_set_cell_size(_map_rid, CELL_SIZE)
	_region.navigation_polygon = poly
	world.add_child(_region)
	NavigationServer2D.region_set_map(_region.get_region_rid(), _map_rid)
	# The server bakes async; a couple of frames later it is queryable.
	_baked = true
	if holes == 0:
		# No obstacles carved -> straight steering is already optimal; keep nav on
		# anyway (harmless), it just returns near-straight paths.
		pass


## The next waypoint on the path from `from` to `to`. Falls back to `to` (steer
## straight) whenever nav is off/unready or the path is trivial/empty.
func next_point(from: Vector2, to: Vector2) -> Vector2:
	if not is_ready():
		return to
	var path: PackedVector2Array = NavigationServer2D.map_get_path(
		_map_rid, from, to, true)
	if path.size() < 2:
		return to
	# path[0] is ~the start; the first meaningful waypoint is path[1].
	# Skip points we have effectively reached so we always aim forward.
	for i in range(path.size()):
		if from.distance_to(path[i]) > CELL_SIZE * 1.5:
			return path[i]
	return to


func clear() -> void:
	if _region != null and is_instance_valid(_region):
		_region.queue_free()
	_region = null
	if _map_rid.is_valid():
		NavigationServer2D.free_rid(_map_rid)
	_map_rid = RID()
	_baked = false


## World-space AABB of a StaticBody2D's first CollisionShape2D (rectangle/circle).
## Returns a zero-size rect when it cannot be measured (skipped by the caller).
func _body_world_rect(body: StaticBody2D) -> Rect2:
	if body == null:
		return Rect2()
	for c: Node in body.get_children():
		if c is CollisionShape2D:
			var cs := c as CollisionShape2D
			var shape: Shape2D = cs.shape
			var center: Vector2 = cs.global_position
			if shape is RectangleShape2D:
				var ext: Vector2 = (shape as RectangleShape2D).size * 0.5
				return Rect2(center - ext, (shape as RectangleShape2D).size)
			elif shape is CircleShape2D:
				var r: float = (shape as CircleShape2D).radius
				return Rect2(center - Vector2(r, r), Vector2(r, r) * 2.0)
			elif shape is CapsuleShape2D:
				var cap := shape as CapsuleShape2D
				var half: Vector2 = Vector2(cap.radius, cap.height * 0.5)
				return Rect2(center - half, half * 2.0)
	return Rect2()
