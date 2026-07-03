class_name TownBuilder
## Builds the handcrafted town of Raven Hollow: ground TileMapLayer (grass +
## stone paths + plaza), districts (inn, smithy, market, cottages, farmstead,
## graveyard), LPC set dressing via AtlasTexture, vegetation and warm lights.
## All atlas rects below were verified by pixel inspection of the sheets.
## Deterministic: a fixed-seed RandomNumberGenerator, no Time-based randomness.

const WORLD_TILES_W: int = 70
const WORLD_TILES_H: int = 50
const TILE: int = 32
const SEED: int = 20260702

const GRASS_SHEET := "res://assets/art/terrain/cainos_grass.png"
const STONE_SHEET := "res://assets/art/terrain/cainos_stone_ground.png"
const DECOR := "res://assets/art/decor/lpc_decorations.png"
const FENCES := "res://assets/art/decor/lpc_fences.png"
const BUILDINGS := "res://assets/art/buildings/"
const PROPS := "res://assets/art/props/"
const PLANTS := "res://assets/art/vegetation/"

# --- lpc_decorations.png rects (pixel-verified) ---
const R_INN_SIGN := Rect2(256, 32, 32, 32)
const R_LANTERN_LIT := Rect2(420, 64, 24, 32)
const R_POLE := Rect2(354, 198, 24, 79)
const R_FOUNTAIN_0 := Rect2(0, 516, 64, 58)
const R_FOUNTAIN_1 := Rect2(64, 516, 64, 58)
const R_FOUNTAIN_2 := Rect2(128, 516, 64, 58)
const R_CART := Rect2(196, 514, 82, 62)  # content x196-277 incl. pull shafts, y514-575
const R_BIG_TREE := Rect2(448, 292, 64, 122)
const R_SMALL_TREE := Rect2(416, 288, 32, 96)  # roots taper down to y383; next sprite at y384
const R_STATUE_HOOD := Rect2(96, 288, 32, 64)
const R_STATUE_WOLF := Rect2(64, 288, 30, 64)
const R_MOUND := Rect2(160, 128, 32, 62)
const R_COUNTER := Rect2(0, 928, 96, 31)  # counter ends y958; white table sprite starts y960
const R_DRAPE_ORANGE := Rect2(272, 800, 48, 64)  # orange awning x272-319, y800-863
const R_DRAPE_GREEN := Rect2(351, 800, 65, 69)  # main green awning x351-415, scallop to y868
const R_ANVIL := Rect2(416, 736, 32, 32)  # single anvil-on-stump x417-445, y737-766
const FIRE_FRAMES := [
	Rect2(256, 1504, 32, 64), Rect2(288, 1504, 32, 64), Rect2(320, 1504, 32, 64),
	Rect2(352, 1504, 32, 64), Rect2(384, 1504, 32, 64),
]
# Gravestone kit (weighted pick list; common stones appear multiple times).
const GRAVE_TYPES := [
	Rect2(64, 96, 32, 32), Rect2(64, 96, 32, 32),
	Rect2(96, 96, 32, 32), Rect2(96, 96, 32, 32),
	Rect2(128, 96, 32, 32), Rect2(64, 128, 32, 32),
	Rect2(128, 128, 32, 32),
	Rect2(160, 32, 32, 32), Rect2(160, 64, 32, 32), Rect2(160, 64, 32, 32),
	Rect2(0, 0, 32, 62), Rect2(32, 14, 64, 48), Rect2(96, 0, 64, 96),
]
# lpc_fences.png 3x3 enclosure kit + single post.
const F_TL := Rect2(0, 64, 32, 32)
const F_T := Rect2(32, 64, 32, 32)
const F_TR := Rect2(64, 64, 32, 32)
# Vertical runs use the full-height post tile (x12-19, connects top+bottom,
# no horizontal rail stubs) — the 3x3 kit's side tiles carry severed rails.
const F_L := Rect2(32, 32, 32, 32)
const F_R := Rect2(32, 32, 32, 32)
const F_BL := Rect2(0, 128, 32, 32)
const F_B := Rect2(32, 128, 32, 32)
const F_BR := Rect2(64, 128, 32, 32)
const F_POST := Rect2(0, 32, 32, 32)

# Graveyard fence rectangle in tile coords (inclusive).
const GY_TX0: int = 7
const GY_TY0: int = 7
const GY_TX1: int = 20
const GY_TY1: int = 17
# Plaza rectangle in tile coords.
const PLAZA := Rect2i(30, 21, 10, 8)

static var _light_tex_cache: GradientTexture2D = null


static func build(parent: Node2D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Secondary stream for the 2026-07 "bustling town" pass so every original
	# placement (grass, old lanes, graves, edge trees) stays byte-identical.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = SEED + 101
	parent.y_sort_enabled = true

	var path_cells: Dictionary = {}
	var ground := _build_ground(rng, rng2, path_cells)
	parent.add_child(ground)

	var decals := Node2D.new()
	decals.name = "Decals"
	decals.z_index = -9
	parent.add_child(decals)

	var props := Node2D.new()
	props.name = "Props"
	props.y_sort_enabled = true
	parent.add_child(props)

	var lights := Node2D.new()
	lights.name = "Lights"
	parent.add_child(lights)

	_world_border(props)
	_plaza(props, decals, lights, rng)
	_inn(props, decals, lights)
	_smithy(props, decals, lights)
	_market(props, decals, lights)
	_cottages(props, decals)
	_farmstead(props, decals, rng)
	_graveyard(props, decals, lights, rng)
	_vegetation(props, decals, rng, path_cells)

	# 2026-07 bustle pass: border forest, orchard, garden plots, roadside
	# dressing, a southern well terminus and ambient villagers.
	_border_forest(props, rng2, path_cells)
	_orchard(props)
	_garden_plots(props, decals)
	_roadside_props(props, lights, rng2)
	_south_terminus(props, lights)
	_villagers(parent, rng2)

	return {
		"player_spawn": Vector2(1120, 950),
		"npc_spawns": {
			"innkeeper": {"pos": Vector2(1120, 648), "wander_radius": 12.0},
			"blacksmith": {"pos": Vector2(1515, 800), "wander_radius": 25.0},
			"merchant": {"pos": Vector2(843, 815), "wander_radius": 10.0},
			"farmer": {"pos": Vector2(1565, 1300), "wander_radius": 60.0},
			"gravekeeper": {"pos": Vector2(455, 470), "wander_radius": 45.0},
			"maid": {"pos": Vector2(1235, 690), "wander_radius": 45.0},
			"wanderer1": {"pos": Vector2(1120, 865), "wander_radius": 95.0},
			"wanderer2": {"pos": Vector2(1130, 1140), "wander_radius": 120.0},
		},
		"bounds": Rect2(0, 0, float(WORLD_TILES_W * TILE), float(WORLD_TILES_H * TILE)),
	}


# ---------------------------------------------------------------- GROUND ----

static func _build_ground(rng: RandomNumberGenerator, rng2: RandomNumberGenerator, path_cells: Dictionary) -> TileMapLayer:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)

	var grass := TileSetAtlasSource.new()
	grass.texture = load(GRASS_SHEET)
	grass.texture_region_size = Vector2i(TILE, TILE)
	for y in range(4):
		for x in range(8):
			grass.create_tile(Vector2i(x, y))
	for y in range(4, 8):
		for x in range(2):
			grass.create_tile(Vector2i(x, y))
	ts.add_source(grass, 0)

	var stone := TileSetAtlasSource.new()
	stone.texture = load(STONE_SHEET)
	stone.texture_region_size = Vector2i(TILE, TILE)
	for y in range(3):
		for x in range(3):
			stone.create_tile(Vector2i(x, y))
	stone.create_tile(Vector2i(6, 1))
	stone.create_tile(Vector2i(3, 3))
	ts.add_source(stone, 1)

	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = ts
	layer.y_sort_enabled = false
	layer.z_index = -10

	# Base grass fill: mostly plain (cols 0-3), ~10% flower/detail (cols 4-7).
	for y in range(WORLD_TILES_H):
		for x in range(WORLD_TILES_W):
			var coords := Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3))
			if rng.randf() < 0.10:
				coords = Vector2i(rng.randi_range(4, 7), rng.randi_range(0, 3))
			layer.set_cell(Vector2i(x, y), 0, coords)

	# Roads / lanes (stone-slab-on-grass tiles).
	var strips: Array = [
		Rect2i(34, 19, 2, 2),   # inn forecourt -> plaza
		Rect2i(34, 29, 2, 14),  # south road to the cottages
		Rect2i(20, 24, 10, 2),  # west road to merchant row
		Rect2i(40, 24, 9, 2),   # east road to the smithy
		Rect2i(15, 23, 5, 2),   # graveyard lane (horizontal)
		Rect2i(13, 18, 2, 6),   # graveyard lane (vertical, ends at the gate)
		Rect2i(36, 35, 15, 2),  # farm lane to the barn
	]
	for s: Rect2i in strips:
		_paint_path(layer, rng, path_cells, s)

	# Newer lanes closing the network into rings (secondary rng keeps the
	# original strips above byte-identical). All checked against footprints.
	var new_strips: Array = [
		Rect2i(44, 26, 2, 10),  # east ring: east road down to the farm lane
		Rect2i(24, 26, 2, 15),  # market lane: west road south past the cart
		Rect2i(26, 39, 8, 2),   # cottage-back lane: market lane -> south road
	]
	for s: Rect2i in new_strips:
		_paint_path(layer, rng2, path_cells, s)

	_paint_plaza(layer, rng, path_cells)
	return layer


static func _paint_path(layer: TileMapLayer, rng: RandomNumberGenerator, path_cells: Dictionary, rect: Rect2i) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			var r: float = rng.randf()
			var row: int = 4
			if r >= 0.9:
				row = 7
			elif r >= 0.8:
				row = 6
			elif r >= 0.5:
				row = 5
			var cell := Vector2i(x, y)
			layer.set_cell(cell, 0, Vector2i(rng.randi_range(0, 1), row))
			path_cells[cell] = true


static func _paint_plaza(layer: TileMapLayer, rng: RandomNumberGenerator, path_cells: Dictionary) -> void:
	var x0: int = PLAZA.position.x
	var y0: int = PLAZA.position.y
	var x1: int = PLAZA.end.x - 1
	var y1: int = PLAZA.end.y - 1
	for y in range(y0, y1 + 1):
		for x in range(x0, x1 + 1):
			var cx: int = 1
			var cy: int = 1
			if x == x0:
				cx = 0
			elif x == x1:
				cx = 2
			if y == y0:
				cy = 0
			elif y == y1:
				cy = 2
			var coords := Vector2i(cx, cy)
			if cx == 1 and cy == 1 and rng.randf() < 0.12:
				coords = Vector2i(6, 1)  # dotted decorative slab
			var cell := Vector2i(x, y)
			layer.set_cell(cell, 1, coords)
			path_cells[cell] = true


# ------------------------------------------------------------- DISTRICTS ----

static func _plaza(props: Node2D, decals: Node2D, lights: Node2D, rng: RandomNumberGenerator) -> void:
	# Animated fountain centerpiece.
	var fountain := _anim_sprite([R_FOUNTAIN_0, R_FOUNTAIN_1, R_FOUNTAIN_2], 5.0, Vector2(1120, 790), 4.0)
	props.add_child(fountain)
	props.add_child(_rect_collider(Vector2(1120, 790), Vector2(56, 30), Vector2(0, -15)))
	lights.add_child(_light(Vector2(1120, 770), Color(0.6, 0.85, 1.0), 0.45, 70.0))

	# Lantern posts on the plaza corners.
	for p: Vector2 in [Vector2(1000, 700), Vector2(1240, 700), Vector2(1000, 930), Vector2(1240, 930)]:
		props.add_child(_lamp_post(p))
		props.add_child(_circle_collider(p, 4.0, Vector2(0, -2)))
		lights.add_child(_light(p + Vector2(0, -62), Color(1.0, 0.78, 0.45), 0.75, 85.0))

	# Stone benches facing the fountain.
	for p: Vector2 in [Vector2(1040, 838), Vector2(1200, 838)]:
		props.add_child(_sprite(PROPS + "cainos_prop_04.png", p, 3.0))
		props.add_child(_rect_collider(p, Vector2(34, 10), Vector2(0, -5)))

	# A couple of crates near the north edge.
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", Vector2(1268, 742), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_23.png", Vector2(980, 745), 3.0))


static func _inn(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var inn := _place_building("house_04.png", Vector2(1120, 610))
	# Hanging INN sign + wall lanterns glued to the facade (drawn over the wall).
	inn.add_child(_atlas_child(R_INN_SIGN, Vector2(-88, -88)))
	inn.add_child(_atlas_child(R_LANTERN_LIT, Vector2(-46, -74)))
	inn.add_child(_atlas_child(R_LANTERN_LIT, Vector2(46, -74)))
	props.add_child(inn)
	lights.add_child(_light(Vector2(1120, 600), Color(1.0, 0.72, 0.42), 0.95, 110.0))
	lights.add_child(_light(Vector2(1074, 555), Color(1.0, 0.78, 0.45), 0.5, 60.0))
	lights.add_child(_light(Vector2(1166, 555), Color(1.0, 0.78, 0.45), 0.5, 60.0))

	# Bench and barrels by the entrance, ivy at the corner.
	props.add_child(_sprite(PROPS + "cainos_prop_04.png", Vector2(1250, 640), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", Vector2(965, 632), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_22.png", Vector2(995, 640), 3.0))
	_decal(decals, PROPS + "szadi_prop_00.png", Vector2(1300, 585))


static func _smithy(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	props.add_child(_place_building("house_00.png", Vector2(1560, 750)))

	# Forge work floor: anvil and fire pit ON the stone patch.
	_decal(decals, PROPS + "szadi_prop_01.png", Vector2(1545, 865))
	props.add_child(_atlas_sprite(R_ANVIL, Vector2(1585, 855), 4.0))
	props.add_child(_circle_collider(Vector2(1585, 855), 9.0, Vector2(0, -6)))
	var fire := _anim_sprite(FIRE_FRAMES, 8.0, Vector2(1508, 855), 4.0)
	props.add_child(fire)
	props.add_child(_circle_collider(Vector2(1508, 855), 9.0, Vector2(0, -5)))
	lights.add_child(_light(Vector2(1508, 838), Color(1.0, 0.6, 0.3), 1.1, 120.0))

	# Fuel and stock piles.
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1665, 810), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_17.png", Vector2(1690, 870), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_06.png", Vector2(1435, 790), 3.0))


static func _market(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	props.add_child(_place_building("house_02.png", Vector2(700, 690)))
	props.add_child(_place_building("house_06.png", Vector2(660, 940)))

	props.add_child(_market_stall(Vector2(812, 772), R_DRAPE_ORANGE))
	props.add_child(_rect_collider(Vector2(812, 772), Vector2(90, 22), Vector2(0, -14)))
	props.add_child(_market_stall(Vector2(868, 902), R_DRAPE_GREEN))
	props.add_child(_rect_collider(Vector2(868, 902), Vector2(90, 22), Vector2(0, -14)))

	# Goods around the stalls + a hand cart parked off the lane.
	props.add_child(_sprite(PROPS + "szadi_prop_15.png", Vector2(756, 838), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_24.png", Vector2(934, 918), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_18.png", Vector2(892, 748), 3.0))
	props.add_child(_atlas_sprite(R_CART, Vector2(760, 1010), 5.0))
	props.add_child(_rect_collider(Vector2(760, 1010), Vector2(52, 18), Vector2(0, -10)))

	props.add_child(_lamp_post(Vector2(905, 830)))
	props.add_child(_circle_collider(Vector2(905, 830), 4.0, Vector2(0, -2)))
	lights.add_child(_light(Vector2(905, 768), Color(1.0, 0.78, 0.45), 0.7, 80.0))


static func _cottages(props: Node2D, decals: Node2D) -> void:
	props.add_child(_place_building("house_01.png", Vector2(980, 1210)))
	props.add_child(_place_building("house_05.png", Vector2(1290, 1230)))

	# Village well beside the south road.
	props.add_child(_sprite(PROPS + "szadi_prop_11.png", Vector2(1200, 1105), 4.0))
	props.add_child(_rect_collider(Vector2(1200, 1105), Vector2(44, 22), Vector2(0, -11)))

	props.add_child(_sprite(PROPS + "szadi_prop_26.png", Vector2(1065, 1225), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", Vector2(1370, 1245), 3.0))
	_decal(decals, PROPS + "szadi_prop_00.png", Vector2(915, 1150))


static func _farmstead(props: Node2D, decals: Node2D, rng: RandomNumberGenerator) -> void:
	props.add_child(_place_building("house_03.png", Vector2(1620, 1240)))
	props.add_child(_place_building("house_07.png", Vector2(1830, 1120)))

	# Hay, crates and logs scattered around the yard.
	props.add_child(_sprite(PROPS + "szadi_prop_14.png", Vector2(1700, 1310), 4.0))
	props.add_child(_circle_collider(Vector2(1700, 1310), 14.0, Vector2(0, -9)))
	props.add_child(_sprite(PROPS + "szadi_prop_29.png", Vector2(1540, 1170), 4.0))
	props.add_child(_circle_collider(Vector2(1540, 1170), 14.0, Vector2(0, -9)))
	props.add_child(_sprite(PROPS + "szadi_prop_12.png", Vector2(1755, 1250), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", Vector2(1900, 1145), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1920, 1210), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_18.png", Vector2(1500, 1265), 3.0))
	var hay_bits: Array = [Vector2(1580, 1330), Vector2(1660, 1180), Vector2(1790, 1300)]
	for p: Vector2 in hay_bits:
		var idx: int = 12 + rng.randi_range(0, 1)
		props.add_child(_sprite(PROPS + "szadi_prop_%02d.png" % idx, p, 3.0))
	_decal(decals, PROPS + "szadi_prop_00.png", Vector2(1745, 1150))


static func _graveyard(props: Node2D, decals: Node2D, lights: Node2D, rng: RandomNumberGenerator) -> void:
	_fence_perimeter(props)

	var left: float = float(GY_TX0 * TILE)
	var top: float = float(GY_TY0 * TILE)
	var right: float = float((GY_TX1 + 1) * TILE)
	var bottom: float = float((GY_TY1 + 1) * TILE)

	# Gnarled clock-tree in the NE corner, a twisted sapling in the SW.
	props.add_child(_atlas_sprite(R_BIG_TREE, Vector2(600, 350), 6.0))
	props.add_child(_circle_collider(Vector2(600, 350), 10.0, Vector2(0, -6)))
	props.add_child(_atlas_sprite(R_SMALL_TREE, Vector2(282, 530), 4.0))
	props.add_child(_circle_collider(Vector2(282, 530), 6.0, Vector2(0, -3)))

	# Statues watching over the yard.
	props.add_child(_atlas_sprite(R_STATUE_HOOD, Vector2(448, 340), 4.0))
	props.add_child(_rect_collider(Vector2(448, 340), Vector2(22, 10), Vector2(0, -5)))
	props.add_child(_atlas_sprite(R_STATUE_WOLF, Vector2(530, 545), 4.0))
	props.add_child(_rect_collider(Vector2(530, 545), Vector2(20, 10), Vector2(0, -5)))

	# Rows of graves with dead-ish spacing (seeded skips + jitter).
	var rows: Array = [336.0, 408.0, 480.0]
	for row_y: float in rows:
		var x: float = 288.0
		while x < 632.0:
			var gx: float = x + rng.randf_range(-6.0, 6.0)
			var skip: bool = rng.randf() < 0.3
			# keep clear of the big tree and the central statue
			if row_y < 380.0 and gx > 545.0:
				skip = true
			if absf(gx - 448.0) < 34.0 and absf(row_y - 340.0) < 30.0:
				skip = true
			if not skip:
				var r: Rect2 = GRAVE_TYPES[rng.randi_range(0, GRAVE_TYPES.size() - 1)]
				props.add_child(_atlas_sprite(r, Vector2(gx, row_y), 2.0))
				props.add_child(_circle_collider(Vector2(gx, row_y), 6.0, Vector2(0, -4)))
				if r.size.y <= 34.0 and rng.randf() < 0.45:
					_decal_rect(decals, R_MOUND, Vector2(gx, row_y + 28.0))
			x += 56.0

	# Ivy creeping across the yard.
	for p: Vector2 in [Vector2(350, 452), Vector2(556, 296), Vector2(262, 300)]:
		_decal(decals, PROPS + "szadi_prop_00.png", p)

	# A lantern by the gate; a worn stone patch outside it.
	var gate := Vector2(464, 610)
	props.add_child(_lamp_post(gate))
	props.add_child(_circle_collider(gate, 4.0, Vector2(0, -2)))
	lights.add_child(_light(gate + Vector2(0, -62), Color(1.0, 0.78, 0.45), 0.7, 85.0))
	_decal(decals, PROPS + "szadi_prop_01.png", Vector2(448, 640))

	# Fence collision (thin strips, gate gap in the south side).
	var mid_y: float = (top + bottom) * 0.5
	var mid_x: float = (left + right) * 0.5
	props.add_child(_rect_collider(Vector2(mid_x, top + 20.0), Vector2(right - left, 10.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(left + 16.0, mid_y), Vector2(12.0, bottom - top - 40.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(right - 16.0, mid_y), Vector2(12.0, bottom - top - 40.0), Vector2.ZERO))
	var gap_x0: float = float(13 * TILE)
	var gap_x1: float = float(15 * TILE)
	props.add_child(_rect_collider(Vector2((left + gap_x0) * 0.5, bottom - 12.0), Vector2(gap_x0 - left, 10.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2((gap_x1 + right) * 0.5, bottom - 12.0), Vector2(right - gap_x1, 10.0), Vector2.ZERO))


static func _fence_perimeter(props: Node2D) -> void:
	for tx in range(GY_TX0, GY_TX1 + 1):
		var top_rect: Rect2 = F_T
		if tx == GY_TX0:
			top_rect = F_TL
		elif tx == GY_TX1:
			top_rect = F_TR
		props.add_child(_fence_tile(top_rect, tx, GY_TY0))

		var bot_rect: Rect2 = F_B
		if tx == GY_TX0:
			bot_rect = F_BL
		elif tx == GY_TX1:
			bot_rect = F_BR
		elif tx == 13 or tx == 14:
			bot_rect = F_POST  # open gate posts
		props.add_child(_fence_tile(bot_rect, tx, GY_TY1))

	for ty in range(GY_TY0 + 1, GY_TY1):
		props.add_child(_fence_tile(F_L, GY_TX0, ty))
		props.add_child(_fence_tile(F_R, GY_TX1, ty))


static func _fence_tile(rect: Rect2, tx: int, ty: int) -> Sprite2D:
	var pos := Vector2(float(tx * TILE + TILE / 2), float(ty * TILE + TILE))
	var s := Sprite2D.new()
	s.texture = _region(FENCES, rect)
	s.centered = false
	s.offset = Vector2(-16.0, -32.0)
	s.position = pos
	return s


# ------------------------------------------------------------ VEGETATION ----

static func _vegetation(props: Node2D, decals: Node2D, rng: RandomNumberGenerator, path_cells: Dictionary) -> void:
	# Big trees around the map edges (kept off the graveyard fence).
	var gy_exclude := Rect2(180, 180, 540, 450)
	var placed: Array = []
	var attempts: int = 0
	while placed.size() < 40 and attempts < 500:
		attempts += 1
		var p := Vector2(rng.randf_range(48.0, 2192.0), rng.randf_range(56.0, 1544.0))
		var in_band: bool = p.x < 210.0 or p.x > 2030.0 or p.y < 200.0 or p.y > 1400.0
		if not in_band:
			continue
		if gy_exclude.has_point(p):
			continue
		var too_close: bool = false
		for q: Vector2 in placed:
			if p.distance_to(q) < 52.0:
				too_close = true
				break
		if too_close:
			continue
		placed.append(p)
		_tree(props, rng.randi_range(0, 2), p)

	# A few hand-set trees inside the town for shade and framing.
	# (1368,1080) and (735,1370) were nudged off the new east-ring road and
	# the new fenced garden plot respectively.
	for p: Vector2 in [Vector2(770, 555), Vector2(1760, 985), Vector2(392, 905), Vector2(1368, 1080), Vector2(735, 1370)]:
		_tree(props, int(absf(p.x)) % 3, p)

	# Bushes hugging the buildings.
	var bushes: Array = [
		Vector2(940, 625), Vector2(1310, 618), Vector2(1445, 762), Vector2(1680, 762),
		Vector2(790, 705), Vector2(575, 955), Vector2(905, 1222), Vector2(1215, 1242),
		Vector2(1540, 1255), Vector2(1900, 1132), Vector2(1055, 1230), Vector2(748, 952),
	]
	for p: Vector2 in bushes:
		var idx: int = rng.randi_range(3, 8)
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % idx, p, 3.0))

	# Sparse grass tufts everywhere (skipping stone/path cells).
	var tufts: int = 0
	var tuft_tries: int = 0
	while tufts < 90 and tuft_tries < 400:
		tuft_tries += 1
		var p := Vector2(rng.randf_range(48.0, 2192.0), rng.randf_range(48.0, 1552.0))
		var cell := Vector2i(int(p.x / 32.0), int(p.y / 32.0))
		if path_cells.has(cell):
			continue
		var idx: int = rng.randi_range(9, 14)
		_decal(decals, PLANTS + "plant_%02d.png" % idx, p)
		tufts += 1


static func _tree(props: Node2D, variant: int, pos: Vector2) -> void:
	# Trunk base sits ~10 px above the image bottom (baked shadow).
	props.add_child(_sprite(PLANTS + "plant_%02d.png" % variant, pos, 10.0))
	props.add_child(_circle_collider(pos, 7.0, Vector2(0, -4)))


# ---------------------------------------------------------- BUSTLE  PASS ----

static func _border_forest(props: Node2D, rng2: RandomNumberGenerator, path_cells: Dictionary) -> void:
	# Dense 2-deep tree wall around the whole map edge. The inner row carries
	# colliders; the outer row is scenery only (unreachable anyway).
	var w := float(WORLD_TILES_W * TILE)
	var h := float(WORLD_TILES_H * TILE)
	var x: float = 44.0
	while x < w - 40.0:
		var jx: float = x + rng2.randf_range(-14.0, 14.0)
		_forest_tree(props, rng2, Vector2(jx, rng2.randf_range(26.0, 46.0)), false, path_cells)
		_forest_tree(props, rng2, Vector2(jx + 38.0, rng2.randf_range(74.0, 104.0)), true, path_cells)
		_forest_tree(props, rng2, Vector2(jx, h - rng2.randf_range(4.0, 24.0)), false, path_cells)
		_forest_tree(props, rng2, Vector2(jx + 38.0, h - rng2.randf_range(52.0, 82.0)), true, path_cells)
		x += 76.0 + rng2.randf_range(-10.0, 10.0)
	var y: float = 140.0
	while y < h - 130.0:
		_forest_tree(props, rng2, Vector2(rng2.randf_range(16.0, 38.0), y), false, path_cells)
		_forest_tree(props, rng2, Vector2(rng2.randf_range(64.0, 96.0), y + 40.0), true, path_cells)
		_forest_tree(props, rng2, Vector2(w - rng2.randf_range(16.0, 38.0), y), false, path_cells)
		_forest_tree(props, rng2, Vector2(w - rng2.randf_range(64.0, 96.0), y + 40.0), true, path_cells)
		y += 82.0 + rng2.randf_range(-10.0, 10.0)


static func _forest_tree(props: Node2D, rng2: RandomNumberGenerator, pos: Vector2, collide: bool, path_cells: Dictionary) -> void:
	var cell := Vector2i(int(pos.x / 32.0), int(pos.y / 32.0))
	if path_cells.has(cell):
		return
	# NOTE: R_BIG_TREE has a clock baked into the trunk (graveyard flavor only)
	# so the forest mixes leafy Cainos trees with the clean gnarled sapling.
	var roll: float = rng2.randf()
	if roll < 0.82:
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % rng2.randi_range(0, 2), pos, 10.0))
	else:
		props.add_child(_atlas_sprite(R_SMALL_TREE, pos, 4.0))
	if collide:
		props.add_child(_circle_collider(pos, 7.0, Vector2(0, -4)))


static func _orchard(props: Node2D) -> void:
	# Small orchard grid behind (south of) the east cottage, west of the ring.
	# Leafy plant_02 trees (the gnarled atlas trees read as a dead grove here).
	for ix in range(4):
		for iy in range(2):
			var p := Vector2(
				1180.0 + 70.0 * float(ix) + (14.0 if iy == 1 else 0.0),
				1340.0 + 72.0 * float(iy))
			props.add_child(_sprite(PLANTS + "plant_02.png", p, 10.0))
			props.add_child(_circle_collider(p, 5.0, Vector2(0, -3)))


static func _garden_plots(props: Node2D, decals: Node2D) -> void:
	# Fenced vegetable plot fronting the cottage-back lane (tiles x26-31 / y41-44).
	var tx0: int = 26
	var ty0: int = 41
	var tx1: int = 31
	var ty1: int = 44
	for tx in range(tx0, tx1 + 1):
		var top_rect: Rect2 = F_T
		if tx == tx0:
			top_rect = F_TL
		elif tx == tx1:
			top_rect = F_TR
		props.add_child(_fence_tile(top_rect, tx, ty0))
		var bot_rect: Rect2 = F_B
		if tx == tx0:
			bot_rect = F_BL
		elif tx == tx1:
			bot_rect = F_BR
		props.add_child(_fence_tile(bot_rect, tx, ty1))
	for ty in range(ty0 + 1, ty1):
		props.add_child(_fence_tile(F_L, tx0, ty))
		props.add_child(_fence_tile(F_R, tx1, ty))

	# Tilled mound rows inside the fence.
	for gx: float in [880.0, 912.0, 944.0, 976.0]:
		_decal_rect(decals, R_MOUND, Vector2(gx, 1382.0))

	# Thin collision ring (decorative plot, fully enclosed).
	var left := float(tx0 * TILE)
	var right := float((tx1 + 1) * TILE)
	var top := float(ty0 * TILE)
	var bottom := float((ty1 + 1) * TILE)
	var mid_x := (left + right) * 0.5
	var mid_y := (top + bottom) * 0.5
	props.add_child(_rect_collider(Vector2(mid_x, top + 24.0), Vector2(right - left, 10.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(mid_x, bottom - 8.0), Vector2(right - left, 10.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(left + 16.0, mid_y), Vector2(12.0, bottom - top - 40.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(right - 16.0, mid_y), Vector2(12.0, bottom - top - 40.0), Vector2.ZERO))


static func _roadside_props(props: Node2D, lights: Node2D, rng2: RandomNumberGenerator) -> void:
	# Signposts at the road junctions.
	var signposts: Array = [
		["cainos_prop_17.png", Vector2(750, 858)],    # west road x market lane
		["cainos_prop_22.png", Vector2(1396, 858)],   # east road x east ring
		["cainos_prop_28.png", Vector2(1076, 1198)],  # south road x farm lane
		["cainos_prop_17.png", Vector2(466, 728)],    # graveyard lane corner
	]
	for s: Array in signposts:
		props.add_child(_sprite(PROPS + String(s[0]), s[1], 2.0))
		props.add_child(_circle_collider(s[1], 3.0, Vector2(0, -2)))

	# Lamp posts along the main roads (warm, sparse).
	var lamps: Array = [
		Vector2(940, 862), Vector2(1350, 752), Vector2(1072, 1000),
		Vector2(1168, 1240), Vector2(760, 1150), Vector2(1490, 1108),
		Vector2(1180, 1424),
	]
	for p: Vector2 in lamps:
		props.add_child(_lamp_post(p))
		props.add_child(_circle_collider(p, 4.0, Vector2(0, -2)))
		lights.add_child(_light(p + Vector2(0, -62), Color(1.0, 0.78, 0.45), 0.65, 80.0))

	# Lived-in clusters near doors and lanes.
	props.add_child(_sprite(PROPS + "cainos_prop_23.png", Vector2(1180, 632), 3.0))   # pots by the inn door
	props.add_child(_sprite(PROPS + "szadi_prop_24.png", Vector2(1062, 634), 3.0))    # grain sack, inn west
	props.add_child(_sprite(PROPS + "szadi_prop_32.png", Vector2(705, 1002), 3.0))    # stack near the cart
	props.add_child(_rect_collider(Vector2(705, 1002), Vector2(30, 12), Vector2(0, -6)))
	props.add_child(_sprite(PROPS + "cainos_prop_31.png", Vector2(628, 986), 3.0))    # pot at shop base
	props.add_child(_sprite(PROPS + "szadi_prop_19.png", Vector2(1652, 905), 3.0))    # brick pile, smithy
	props.add_child(_sprite(PROPS + "cainos_prop_27.png", Vector2(1015, 764), 3.0))   # plaza pot NW
	props.add_child(_sprite(PROPS + "cainos_prop_23.png", Vector2(1228, 764), 3.0))   # plaza pots NE

	# Wood piles by the barn.
	props.add_child(_sprite(PROPS + "szadi_prop_25.png", Vector2(1560, 1300), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_23.png", Vector2(1748, 1338), 3.0))

	# Tree clusters framing lanes and the backs of houses.
	var road_trees: Array = [
		Vector2(890, 470), Vector2(1350, 465),    # flanking the inn rear
		Vector2(1420, 545), Vector2(1715, 600),   # behind the smithy
		Vector2(540, 900), Vector2(528, 1120),    # behind merchant row
		Vector2(690, 1085),                        # market lane, west side
		Vector2(1330, 885),                        # east road, south side
		Vector2(1700, 935),                        # smithy yard edge
		Vector2(1850, 1330), Vector2(1960, 1400), # southeast meadow
		Vector2(250, 1000), Vector2(320, 1180),   # west meadow
	]
	for p: Vector2 in road_trees:
		_tree(props, int(absf(p.x + p.y)) % 3, p)

	# Bushes hugging road edges.
	var bushes: Array = [
		Vector2(1070, 985), Vector2(1180, 995), Vector2(935, 940),
		Vector2(1310, 848), Vector2(828, 700), Vector2(848, 1200),
		Vector2(1160, 1390), Vector2(555, 812), Vector2(1435, 1195),
		Vector2(1210, 1052),
	]
	for p: Vector2 in bushes:
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % rng2.randi_range(3, 8), p, 3.0))

	# A few rocks off the lanes.
	var rocks: Array = [
		["cainos_prop_34.png", Vector2(470, 850)],
		["cainos_prop_36.png", Vector2(1180, 1160)],
		["cainos_prop_38.png", Vector2(1395, 1244)],
		["cainos_prop_40.png", Vector2(2005, 1180)],
		["cainos_prop_35.png", Vector2(870, 1050)],
	]
	for r: Array in rocks:
		props.add_child(_sprite(PROPS + String(r[0]), r[1], 2.0))


static func _south_terminus(props: Node2D, lights: Node2D) -> void:
	# The south road ends at a second, larger village well with a bench.
	props.add_child(_sprite(PROPS + "cainos_prop_30.png", Vector2(1120, 1445), 6.0))
	props.add_child(_rect_collider(Vector2(1120, 1445), Vector2(78, 30), Vector2(0, -18)))
	props.add_child(_sprite(PROPS + "cainos_prop_04.png", Vector2(1040, 1462), 3.0))
	props.add_child(_rect_collider(Vector2(1040, 1462), Vector2(34, 10), Vector2(0, -5)))
	lights.add_child(_light(Vector2(1120, 1425), Color(0.6, 0.85, 1.0), 0.35, 55.0))


static func _villagers(parent: Node2D, rng2: RandomNumberGenerator) -> void:
	# Ambient wandering townsfolk spread along the road network.
	# Explicit look pool: every (sheet, variant) combo EXCEPT the 7 named-cast
	# combos (female1 v0, male2 v1, male3 v2, male4 v0, male2 v3, female2 v1,
	# male1 v2) and the 6 playable-class combos (male1 v0, male4 v3,
	# female2 v3, male1 v1, male3 v1, male2 v0) — 11 free combos, drawn
	# WITHOUT replacement so no two villagers (or look-alikes) match.
	var pool: Array = [
		["npc_male1", 3],
		["npc_male2", 2],
		["npc_male3", 0], ["npc_male3", 3],
		["npc_male4", 1], ["npc_male4", 2],
		["npc_female1", 1], ["npc_female1", 2], ["npc_female1", 3],
		["npc_female2", 0], ["npc_female2", 2],
	]
	var folk: Array = [
		["Old Tomas", Vector2(1100, 880), "Mind the carts, lad."],
		["Berta", Vector2(800, 800), "Fresh hay, just in."],
		["Cedric", Vector2(1380, 800), "The forge's been roaring since dawn."],
		["Mira", Vector2(795, 1040), "Market day tomorrow, bright and early."],
		["Ansel", Vector2(1120, 1050), "The well water's sweet this year."],
		["Greta", Vector2(950, 1280), "These beds want weeding again."],
		["Rolf", Vector2(1400, 1150), "Barn roof held through the storm, thank the saints."],
		["Ida", Vector2(520, 770), "Keep clear of the old yard after dark."],
		["Petrik", Vector2(1170, 700), "The inn pours a fine dark ale."],
		["Lena", Vector2(1060, 1408), "Wolves in the border pines, they say."],
	]
	for i in range(folk.size()):
		var row: Array = folk[i]
		var pick: Array = pool.pop_at(rng2.randi_range(0, pool.size() - 1))
		var def := {
			"id": "villager_%d" % i,
			"display_name": String(row[0]),
			"sheet": "res://assets/art/characters/%s.png" % String(pick[0]),
			"variant": int(pick[1]),
			"pos": row[1],
			"wander_radius": rng2.randf_range(70.0, 150.0),
			"dialogue": [String(row[2])],
			"facing": "down",
		}
		parent.add_child(NPC.create(def))


# --------------------------------------------------------------- HELPERS ----

static func _place_building(file_name: String, pos: Vector2) -> Node2D:
	var tex: Texture2D = load(BUILDINGS + file_name)
	var w: float = float(tex.get_width())
	var h: float = float(tex.get_height())
	var node := Node2D.new()
	node.position = pos
	var spr := Sprite2D.new()
	spr.texture = tex
	spr.centered = false
	spr.offset = Vector2(w * -0.5, -h + 8.0)  # pos = bottom-center wall line
	node.add_child(spr)
	node.add_child(_rect_collider(Vector2.ZERO, Vector2(w - 16.0, 54.0), Vector2(0, -27)))
	return node


static func _market_stall(pos: Vector2, drape: Rect2) -> Node2D:
	var stall := Node2D.new()
	stall.position = pos
	var counter := Sprite2D.new()
	counter.texture = _region(DECOR, R_COUNTER)
	counter.centered = false
	counter.offset = Vector2(-48.0, -31.0)  # counter bottom on the feet line
	stall.add_child(counter)
	var roof := Sprite2D.new()
	roof.texture = _region(DECOR, drape)
	roof.centered = false
	roof.offset = Vector2(drape.size.x * -0.5, -drape.size.y)
	roof.position = Vector2(0, -28)  # fringe overlaps the counter top (-31) slightly
	stall.add_child(roof)
	return stall


static func _lamp_post(pos: Vector2) -> Node2D:
	var post := Node2D.new()
	post.position = pos
	var pole := Sprite2D.new()
	pole.texture = _region(DECOR, R_POLE)
	pole.centered = false
	pole.offset = Vector2(-12.0, -77.0)
	post.add_child(pole)
	var lamp := Sprite2D.new()
	lamp.texture = _region(DECOR, R_LANTERN_LIT)
	lamp.position = Vector2(0, -62)
	post.add_child(lamp)
	return post


static func _sprite(path: String, pos: Vector2, skirt: float = 4.0) -> Sprite2D:
	var tex: Texture2D = load(path)
	var s := Sprite2D.new()
	s.texture = tex
	s.centered = false
	s.offset = Vector2(float(tex.get_width()) * -0.5, -float(tex.get_height()) + skirt)
	s.position = pos
	return s


static func _atlas_sprite(rect: Rect2, pos: Vector2, skirt: float = 4.0) -> Sprite2D:
	var s := Sprite2D.new()
	s.texture = _region(DECOR, rect)
	s.centered = false
	s.offset = Vector2(rect.size.x * -0.5, -rect.size.y + skirt)
	s.position = pos
	return s


static func _atlas_child(rect: Rect2, rel_pos: Vector2) -> Sprite2D:
	# Centered piece glued onto a parent container (signs, wall lanterns).
	var s := Sprite2D.new()
	s.texture = _region(DECOR, rect)
	s.position = rel_pos
	return s


static func _decal(decals: Node2D, path: String, center: Vector2) -> void:
	var tex: Texture2D = load(path)
	var s := Sprite2D.new()
	s.texture = tex
	s.position = center
	decals.add_child(s)


static func _decal_rect(decals: Node2D, rect: Rect2, center: Vector2) -> void:
	var s := Sprite2D.new()
	s.texture = _region(DECOR, rect)
	s.position = center
	decals.add_child(s)


static func _region(sheet_path: String, rect: Rect2) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(sheet_path)
	at.region = rect
	return at


static func _anim_sprite(frames: Array, fps: float, pos: Vector2, skirt: float) -> AnimatedSprite2D:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("loop")
	sf.set_animation_speed("loop", fps)
	sf.set_animation_loop("loop", true)
	var size := Vector2.ZERO
	for r: Rect2 in frames:
		sf.add_frame("loop", _region(DECOR, r))
		size = r.size
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.centered = false
	spr.offset = Vector2(size.x * -0.5, -size.y + skirt)
	spr.position = pos
	spr.autoplay = "loop"
	return spr


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


static func _rect_collider(pos: Vector2, size: Vector2, center_off: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	cs.shape = shape
	cs.position = center_off
	body.add_child(cs)
	return body


static func _circle_collider(pos: Vector2, radius: float, center_off: Vector2) -> StaticBody2D:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	body.position = pos
	var cs := CollisionShape2D.new()
	var shape := CircleShape2D.new()
	shape.radius = radius
	cs.shape = shape
	cs.position = center_off
	body.add_child(cs)
	return body


static func _world_border(props: Node2D) -> void:
	var w: float = float(WORLD_TILES_W * TILE)
	var h: float = float(WORLD_TILES_H * TILE)
	props.add_child(_rect_collider(Vector2(w * 0.5, 4.0), Vector2(w, 8.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(w * 0.5, h - 4.0), Vector2(w, 8.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(4.0, h * 0.5), Vector2(8.0, h), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(w - 4.0, h * 0.5), Vector2(8.0, h), Vector2.ZERO))
