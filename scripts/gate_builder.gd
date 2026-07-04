class_name GateBuilder
## Phase C §2 — the town's east gate: a stone gatehouse (arched, raised
## portcullis) straddling the smithy road at the town's east edge, with a
## crenellated wall line flanking north and south into the border forest,
## a lit lantern each side of the arch mouth, warm PointLight2Ds, colliders
## that leave only the road corridor open, and a stone-path strip extending
## TownBuilder's east road (ends at tile x49) to the wall.
##
## Sprites are crops of _downloads/wilderness/gate/castle2.png (Hyptosis,
## CC-BY 3.0 — see assets/art/wilderness/CREDITS_WILD.txt), copied into
## res://assets/art/wilderness/. All rects pixel-verified 2026-07-03:
##   gate_arch.png    = castle2 (96,64)-(192,192)  96x128, pillar feet at
##                      crop-local y127 (sheet y191); arch opening local
##                      x16-80 is transparent, portcullis spikes hang raised.
##   gate_wall.png    = castle2 (0,68)-(64,178)    64x110, merlon caps on
##                      top, brick base at local y109 (sheet y177).
##   gate_lantern.png = castle2 (132,194)-(164,226) 32x32 lit hanging lantern.
##
## INTEGRATION (wired by the integration pass, NOT by this file):
##  * Call site — main.gd (after TownBuilder.build) or the end of
##    TownBuilder.build itself:
##        var gate_tp: Vector2 = GateBuilder.add_gate(world_node)
##    The returned position equals MapRegistry.get_travel_point("town",
##    "east_gate")["pos"] (Vector2(2192, 816)); main.gd's travel loop uses the
##    MapRegistry value, so nothing needs to consume the return unless handy.
##  * town_builder.gd: _border_forest plants random trees along the east edge
##    and will overlap the wall — integrator adds a keep-clear rect like the
##    existing CLEAR_TERMINUS, e.g.
##        const CLEAR_GATE := Rect2(2080.0, 540.0, 160.0, 520.0)
##    (trees just OUTSIDE that rect hugging the wall ends at y~552/y~1044 are
##    desirable — they sell "the wall runs into the forest").
##  * npc_data.gd / main.gd: guard NPC "Gatewarden Iosif" beside the gate —
##    suggested spawn Vector2(2144.0, 866.0), wander_radius 8.0, dialogue
##    warning about wolves and the night (spec §2).
##  * Day/night pass: the two lantern lights + tunnel glow are added to the
##    town's existing "Lights" container (created by TownBuilder), so any
##    night-time energy ramp that scans that node picks them up for free.

const ART_DIR := "res://assets/art/wilderness/"
const ARCH_TEX := ART_DIR + "gate_arch.png"
const WALL_TEX := ART_DIR + "gate_wall.png"
const LANTERN_TEX := ART_DIR + "gate_lantern.png"
const GRASS_SHEET := "res://assets/art/terrain/cainos_grass.png"

const TILE: int = 32
const SEED: int = 20260703

## Arch base center: town east edge (bounds x = 2240), on the smithy-road line
## (road tiles y24-25 = world y768-832). Gatehouse sprite spans x2144-2240.
const GATE_POS := Vector2(2192.0, 846.0)
## Travel point sits mid-tunnel; MapRegistry.TOWN_EAST_GATE must stay in sync.
const TRAVEL_OFFSET := Vector2(0.0, -30.0)

## Flanking wall bases as y-offsets from the arch base. North pair rises
## behind the gatehouse (draw order via y-sort); south pair starts exactly at
## the arch base line so the brick runs seamless. Wall drawn span per piece is
## base-110..base, steps of 88 keep 22 px of brick overlap between pieces.
const FLANK_BASE_OFFSETS := [-184.0, -96.0, 110.0, 198.0]

## Road strip: continues TownBuilder's east road (Rect2i(40,24,9,2), ends at
## tile x49) through the gate to the map edge.
const ROAD_TILES := Rect2i(49, 24, 21, 2)

const WARM := Color(1.0, 0.78, 0.45)
const TUNNEL_GLOW := Color(1.0, 0.74, 0.4)
const TUNNEL_DARK := Color(0.05, 0.045, 0.07, 0.9)

static var _light_tex_cache: GradientTexture2D = null


static func add_gate(parent: Node2D, gate_pos: Vector2 = GATE_POS, paint_road: bool = true) -> Vector2:
	## Builds the east gatehouse composite under `parent` (the World node the
	## town was built into) and returns the travel-point position at the arch.
	## Reuses the town's "Props" (y-sorted) and "Lights" containers when they
	## exist; otherwise creates its own.
	var props := _find_or_make(parent, "Props", true)
	var lights := _find_or_make(parent, "Lights", false)

	if paint_road:
		parent.add_child(_road_layer())

	# Flanking wall line (alternate flip_h to break brick repetition).
	var flip := false
	for off: float in FLANK_BASE_OFFSETS:
		props.add_child(_wall_piece(Vector2(gate_pos.x, gate_pos.y + off), flip))
		flip = not flip

	props.add_child(_gatehouse(gate_pos))

	# Colliders: wall line solid, road corridor (y792-840 at default pos) open.
	props.add_child(_collider(gate_pos + Vector2(0.0, -195.0), Vector2(48.0, 198.0)))  # north flank
	props.add_child(_collider(gate_pos + Vector2(0.0, -100.0), Vector2(96.0, 92.0)))   # gatehouse, north of corridor
	props.add_child(_collider(gate_pos + Vector2(0.0, 17.0), Vector2(96.0, 46.0)))     # gatehouse, south of corridor
	props.add_child(_collider(gate_pos + Vector2(0.0, 99.0), Vector2(48.0, 198.0)))    # south flank

	# Warm lantern light each side of the arch mouth + a faint tunnel glow.
	lights.add_child(_light(gate_pos + Vector2(-32.0, -60.0), WARM, 0.55, 60.0))
	lights.add_child(_light(gate_pos + Vector2(32.0, -60.0), WARM, 0.55, 60.0))
	lights.add_child(_light(gate_pos + Vector2(0.0, -26.0), TUNNEL_GLOW, 0.3, 55.0))

	return gate_pos + TRAVEL_OFFSET


# ------------------------------------------------------------------ PARTS ----

static func _gatehouse(pos: Vector2) -> Node2D:
	var gate := Node2D.new()
	gate.name = "EastGate"
	gate.position = pos

	# Dark tunnel backing drawn behind the sprite: shows only through the
	# transparent arch opening, so the passage reads as shadowed depth and a
	# player walking in (drawn earlier by y-sort) ghosts through the dark.
	var backing := Polygon2D.new()
	backing.polygon = PackedVector2Array([
		Vector2(-32.0, -60.0), Vector2(32.0, -60.0),
		Vector2(32.0, 2.0), Vector2(-32.0, 2.0),
	])
	backing.color = TUNNEL_DARK
	gate.add_child(backing)

	var arch := Sprite2D.new()
	arch.texture = load(ARCH_TEX)
	arch.centered = false
	arch.offset = Vector2(-48.0, -126.0)  # 96x128, 2 px skirt below pillar feet
	gate.add_child(arch)

	# Lit lanterns flanking the arch mouth (glued to the pillars' inner edges).
	for sx: float in [-32.0, 32.0]:
		var lamp := Sprite2D.new()
		lamp.texture = load(LANTERN_TEX)
		lamp.position = Vector2(sx, -60.0)
		gate.add_child(lamp)

	return gate


static func _wall_piece(base_pos: Vector2, flip: bool) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = load(WALL_TEX)
	s.centered = false
	s.offset = Vector2(-32.0, -108.0)  # 64x110, 2 px skirt below brick base
	s.position = base_pos
	s.flip_h = flip
	return s


static func _road_layer() -> TileMapLayer:
	# Same slab-on-grass tiles and row weighting as TownBuilder._paint_path.
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var grass := TileSetAtlasSource.new()
	grass.texture = load(GRASS_SHEET)
	grass.texture_region_size = Vector2i(TILE, TILE)
	for y in range(4, 8):
		for x in range(2):
			grass.create_tile(Vector2i(x, y))
	ts.add_source(grass, 0)

	var layer := TileMapLayer.new()
	layer.name = "GateRoad"
	layer.tile_set = ts
	layer.y_sort_enabled = false
	# Same z as the town Ground layer; added later in the tree, so it draws
	# over the grass fill and under the Decals layer (z -9).
	layer.z_index = -10

	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	for y in range(ROAD_TILES.position.y, ROAD_TILES.end.y):
		for x in range(ROAD_TILES.position.x, ROAD_TILES.end.x):
			var r: float = rng.randf()
			var row: int = 4
			if r >= 0.9:
				row = 7
			elif r >= 0.8:
				row = 6
			elif r >= 0.5:
				row = 5
			layer.set_cell(Vector2i(x, y), 0, Vector2i(rng.randi_range(0, 1), row))
	return layer


# ---------------------------------------------------------------- HELPERS ----

static func _find_or_make(parent: Node2D, node_name: String, ysort: bool) -> Node2D:
	var existing := parent.get_node_or_null(node_name)
	if existing is Node2D:
		return existing as Node2D
	var n := Node2D.new()
	n.name = "Gate" + node_name
	n.y_sort_enabled = ysort
	parent.add_child(n)
	return n


static func _collider(center: Vector2, size: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = center
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	body.add_child(cs)
	return body


static func _light(pos: Vector2, color: Color, energy: float, radius: float) -> PointLight2D:
	var l := PointLight2D.new()
	l.texture = _light_texture()
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 128.0
	return l


static func _light_texture() -> GradientTexture2D:
	if _light_tex_cache != null:
		return _light_tex_cache
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 1.0])
	g.colors = PackedColorArray([
		Color(1, 1, 1, 1), Color(1, 1, 1, 0.35), Color(1, 1, 1, 0),
	])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.5, 0.0)
	tex.width = 256
	tex.height = 256
	_light_tex_cache = tex
	return tex
