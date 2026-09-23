class_name TownBuilder
## Builds the handcrafted town of Raven Hollow: ground TileMapLayer (grass +
## stone paths + plaza), districts (inn, smithy, market, cottages, farmstead,
## graveyard), LPC set dressing via AtlasTexture, vegetation and warm lights.
## All atlas rects below were verified by pixel inspection of the sheets.
## Deterministic: a fixed-seed RandomNumberGenerator, no Time-based randomness.

# RAVEN HOLLOW CITY (owner 2026-09-13, design/RAVEN_HOLLOW_CITY.md): the map is
# now 224x160 tiles; the original 70x50 village (the Hollow) keeps its coordinates
# as district 1 and every placement below stays byte-identical. The city is built
# by TownCity after the village pass.
const WORLD_TILES_W: int = 224
const WORLD_TILES_H: int = 160
const HOLLOW_TILES_W: int = 70
const HOLLOW_TILES_H: int = 50
const TILE: int = 32
const SEED: int = 20260702

# Kept-open clearings: random edge trees (the y>1400 band in _vegetation and
# the _border_forest wall) must not swallow the south-terminus well/bench or
# the fenced garden plot. Sized for the tallest tree canopy (139 px, base-sorted).
const CLEAR_TERMINUS := Rect2(980.0, 1390.0, 280.0, 210.0)
const CLEAR_GARDEN := Rect2(800.0, 1290.0, 260.0, 270.0)
# PAINTED GROUND (Fable, 2026-09-12): the village pond in the SW meadow —
# random edge trees and tufts stay off the water and its banks.
const CLEAR_POND := Rect2(400.0, 1260.0, 330.0, 200.0)
const POND_CENTER := Vector2(560.0, 1350.0)
# Ground tint: LPC Terrains grass is a bright spring green; the anchor palette
# (design/STYLE_ANCHOR.md) wants muted olive parchment. Applied to the whole
# painted ground stack (overlay inherits).
const GROUND_TINT := Color(0.94, 0.82, 0.50)
# CITY v7: the city's cobble/flag overlay is NOT multiplied by GROUND_TINT
# (that made every street mustard and the Trade Square sand); it gets its
# own warm-grey stone tint. The village overlay keeps GROUND_TINT (byte-identical).
const CITY_STONE_TINT := Color(0.90, 0.86, 0.80)
# v8: the two flagged plazas were the lightest surface on the map (Stone_White
# x GROUND_TINT reads as sand); they get their own layer at a mid warm grey.
const SQUARE_TINT := Color(0.72, 0.71, 0.68)
const CITY_EARTH_TINT := Color(0.97, 0.97, 0.96)
# Gate keep-clear (contract §14 / GateBuilder): the east-gate mouth to
# MapRegistry.TOWN_EAST_GATE (2192,816). The border forest must not wall this
# band or the gate art / the road out of town would be blocked. main.gd builds
# the gate art here via GateBuilder.add_gate — town_builder only leaves the gap.
const CLEAR_GATE := Rect2(2080.0, 540.0, 160.0, 520.0)

const GRASS_SHEET := "res://assets/art/terrain/cainos_grass.png"
const STONE_SHEET := "res://assets/art/terrain/cainos_stone_ground.png"
const DECOR := "res://assets/art/decor/lpc_decorations.png"
const FENCES := "res://assets/art/decor/lpc_fences.png"
const BUILDINGS := "res://assets/art/buildings/"
const PROPS := "res://assets/art/props/"
const PLANTS := "res://assets/art/vegetation/"
const TOWN_KIT := "res://assets/art/world/town/"   # polish kit (tools/assets/extract_town_kit.py)

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
## QA: lane/plaza/yard cells of the last build (TownAudit reads it; RH_PROPAUDIT=1).
static var last_path_cells: Dictionary = {}


static func build(parent: Node2D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	# Secondary stream for the 2026-07 "bustling town" pass so every original
	# placement (grass, old lanes, graves, edge trees) stays byte-identical.
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = SEED + 101
	parent.y_sort_enabled = true

	var path_cells: Dictionary = {}
	# PAINTED GROUND (Fable, 2026-09-12): corner-autotiled LPC Terrains ground
	# (grass / worn dirt lanes / cobble plaza / soil plots / pond) replaces the
	# single-material grass fill + slab strips. The legacy builder still runs
	# into a throwaway layer so `rng`/`rng2` consume exactly the same draws —
	# every prop, grave, tree and tuft placement below stays byte-identical.
	var legacy_cells: Dictionary = {}
	var legacy := _build_ground(rng, rng2, legacy_cells)
	legacy.free()
	var ground := _build_ground_painted(path_cells)
	parent.add_child(ground)
	last_path_cells = path_cells

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

	# SW wood-gatherer's clearing (sitting #1: bottom-left dead field).
	# (POLISH 2026-09: clustered around a chopping stump — one story, not confetti)
	props.add_child(_sprite(PROPS + "szadi_prop_22.png", Vector2(336, 1232), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(300, 1254), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_25.png", Vector2(368, 1260), 2.0))
	props.add_child(_sprite(PROPS + "szadi_prop_17.png", Vector2(352, 1212), 2.0))
	props.add_child(_sprite(PROPS + "cainos_prop_36.png", Vector2(304, 1206), 2.0))
	props.add_child(_sprite(PROPS + "szadi_prop_13.png", Vector2(380, 1226), 2.0))
	_world_border(props)
	# RAVEN HOLLOW V2 (owner 2026-07-12): the town rebuilt from scratch on the
	# generated library — same anatomy (NPC/station/gate anchors byte-equal),
	# new hand-authored dressing throughout. Old builders retired below.
	# OWNER RULING 2026-07-12: generated assets REJECTED for the town read —
	# v1 (Szadi/LPC/Cainos human-made art) restored; v3 free-pack rebuild next.
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
	# POLISH 2026-09 (Fable): owned yards, crops, paddock, pond bank, roadside
	# saint, ruin ring, chimney smoke, door lights — see _polish_2026_09.
	_polish_2026_09(props, decals, lights)
	# RAVEN HOLLOW CITY S1 (owner 2026-09-13): walls, gates, keep, cathedral,
	# canals, bridges, harbor, squares — see scripts/town_city.gd.
	TownCity.build(props, decals, lights)
	# RAVEN HOLLOW CITY v3 life pass: city folk, vendors, guards (scripts/town_life.gd).
	TownLife.populate(parent)

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
			# Gatewarden Iosif holds the east gate (contract §11). Kept ~69 px
			# from the east-gate travel point (2192,816) and its 8 px wander is
			# tight, so a single E press never collides with the gate travel
			# prompt (spatial exclusivity, contract §3.5).
			"gatewarden": {"pos": Vector2(2144, 866), "wander_radius": 8.0},
		},
		"bounds": Rect2(0, 0, float(WORLD_TILES_W * TILE), float(WORLD_TILES_H * TILE)),
		# Crafting stations (contract §7, spec §6b): main.gd's station loop
		# (§3.5) shows the prompt and opens crafting_ui.open_station(id) on E.
		# forge = Goran's anvil (drawn at 1585,855) + (0,16) walkable stand;
		# hearth = the inn hearth, read from the courtyard south of the inn.
		# Wilderness ships NO stations.
		"stations": [
			{"id": "forge", "pos": Vector2(1585, 871), "radius": 30.0, "prompt": "[E] Craft — Goran's Forge"},
			{"id": "hearth", "pos": Vector2(1120, 620), "radius": 30.0, "prompt": "[E] Craft — The Inn Hearth"},
		],
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
		Rect2i(15, 24, 5, 2),   # graveyard lane (horizontal, meets the west road row)
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
	# Worn transition fringe (sitting #1: the plaza ended in razor-straight
	# edges against grass). A ring of cracked partial slabs bleeds the square
	# into the green, denser at the middles of each side, sparse at corners.
	for y in range(y0 - 1, y1 + 2):
		for x in range(x0 - 1, x1 + 2):
			var on_ring: bool = x == x0 - 1 or x == x1 + 1 or y == y0 - 1 or y == y1 + 1
			var cell2 := Vector2i(x, y)
			if not on_ring or path_cells.has(cell2):
				continue
			if rng.randf() < 0.62:
				layer.set_cell(cell2, 0, Vector2i(rng.randi_range(0, 1), rng.randi_range(4, 7)))
				path_cells[cell2] = true


# -------------------------------------------------------- PAINTED GROUND ----

## Corner-autotiled ground for Raven Hollow (TerrainPainter over LPC Terrains
## v7). Two layers: BASE (grass hub + dirt lanes/yards + soil plots + pond)
## and a keyed OVERLAY (cobble plaza) so cobble edges sit straight on dirt.
## Every non-grass cell is registered in `path_cells` (tuft/tree keep-clear).
## CITY v7: move every overlay cell outside the village's 70x50 tiles to a
## sibling layer with the city's stone tint (same tiles, same rng choices).
static func _split_city_overlay(over: TileMapLayer, parent: TileMapLayer) -> void:
	var city := TileMapLayer.new()
	city.name = "GroundOverlayCity"
	city.tile_set = TerrainPainter.make_tileset(true, true)   # v8: no grass lip on city paving
	city.y_sort_enabled = false
	city.z_index = 0
	city.modulate = CITY_STONE_TINT
	for c: Vector2i in over.get_used_cells():
		if c.x < 70 and c.y < 50:
			continue
		city.set_cell(c, 0, over.get_cell_atlas_coords(c))
		over.erase_cell(c)
	# de-weed the carriageway: Mudstone_Gray solo tiles 793/858 carry baked
	# yellow sprigs and _pick_solo favours 793 - swap 90% for the clean fills
	var cols: int = int(TerrainPainter._data["columns"])
	var weedy: Array = [Vector2i(793 % cols, 793 / cols), Vector2i(858 % cols, 858 / cols)]
	var clean: Array = [Vector2i(856 % cols, 856 / cols), Vector2i(857 % cols, 857 / cols), Vector2i(1354 % cols, 1354 / cols)]
	var wr := RandomNumberGenerator.new()
	wr.seed = SEED + 707
	for c2: Vector2i in city.get_used_cells():
		if weedy.has(city.get_cell_atlas_coords(c2)) and wr.randf() < 0.9:
			city.set_cell(c2, 0, clean[wr.randi_range(0, 2)])
	# v8: the pale flags (Stone_White / Stone_Tan) move to their own layer so
	# the plazas can sit at a mid value instead of reading as sand at noon and
	# beach at dusk.
	var squares := TileMapLayer.new()
	squares.name = "GroundOverlaySquares"
	squares.tile_set = city.tile_set
	squares.y_sort_enabled = false
	squares.z_index = 0
	squares.modulate = SQUARE_TINT
	var pale: Array = TerrainPainter.atlas_coords_for([TerrainPainter.mat("Stone_White"), TerrainPainter.mat("Stone_Tan")])
	for c3: Vector2i in city.get_used_cells():
		if pale.has(city.get_cell_atlas_coords(c3)):
			squares.set_cell(c3, 0, city.get_cell_atlas_coords(c3))
			city.erase_cell(c3)
	parent.add_child(city)
	parent.add_child(squares)


## v8: every SOLO Dirt_Roots cell of the city gets re-drawn on its own layer,
## desaturated: Dirt_Roots x GROUND_TINT is a saturated orange that turned the
## terrace backs, shoulders and yards into orange slabs. Transition cells keep
## the base tint (their grass half must not be touched), so the change stops at
## a one-tile rim that the ground wash covers. Village cells are never copied.
static func _city_earth(base_layer: TileMapLayer, painted: Dictionary) -> TileMapLayer:
	var earth := TileMapLayer.new()
	earth.name = "GroundCityEarth"
	earth.tile_set = base_layer.tile_set
	earth.y_sort_enabled = false
	earth.z_index = 0
	earth.modulate = CITY_EARTH_TINT
	var sh := Shader.new()
	# v8: an explicit per-channel gain, not a luminance mix - the 2D pipeline is
	# not sRGB-weighted here, so mixing toward dot(rgb, 0.3/0.59/0.11) DARKENS
	# the tile instead of desaturating it (measured: brown setts 136,95,53 ->
	# 71,44,17). Lifting blue and green against red turns the saturated root
	# dirt into trodden earth with no value loss.
	sh.code = "shader_type canvas_item;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV);\n\tc.rgb *= vec3(0.89, 1.12, 1.50);\n\tCOLOR = c * COLOR;\n}\n"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	earth.material = mat
	var dirt_id: int = TerrainPainter.mat("Dirt_Roots")
	var cols_e: int = int(TerrainPainter._data["columns"])
	var solo_only: Array = []
	for t_v: Variant in (TerrainPainter._solo.get(dirt_id, []) as Array):
		var t: int = int(t_v)
		solo_only.append(Vector2i(t % cols_e, t / cols_e))
	for c: Variant in painted:
		var cell: Vector2i = c
		if cell.x < 70 and cell.y < 50:
			continue
		var co2: Vector2i = base_layer.get_cell_atlas_coords(cell)
		if solo_only.has(co2):
			earth.set_cell(cell, 0, co2)
	return earth


static func _build_ground_painted(path_cells: Dictionary) -> TileMapLayer:
	var rng3 := RandomNumberGenerator.new()
	rng3.seed = SEED + 202
	var grass: int = TerrainPainter.mat("Grass")
	var dirt: int = TerrainPainter.mat("Dirt_Roots")
	var soil: int = TerrainPainter.mat("Soil")
	var shallows: int = TerrainPainter.mat("Water_Shallows_Dirt")
	var water: int = TerrainPainter.mat("Water")
	var cobble: int = TerrainPainter.mat("Mudstone_Gray")
	var base := TerrainPainter.Canvas.new(WORLD_TILES_W, WORLD_TILES_H, grass)
	var top := TerrainPainter.Canvas.new(WORLD_TILES_W, WORLD_TILES_H, grass)
	var top2 := TerrainPainter.Canvas.new(WORLD_TILES_W, WORLD_TILES_H, grass)   # v8 accent paving

	# --- LANES: worn dirt, 2-3 tiles wide with organic edges (Bible rule 25:
	# no ruler roads — every lane carries interior waypoints and lateral drift).
	var main_w: float = 42.0
	var lane_w: float = 33.0
	# main street: plaza east edge -> smithy -> east gate (MapRegistry TOWN_EAST_GATE);
	# drifts a tile either way so the edge never reads as a ruler
	base.band([Vector2(1250, 800), Vector2(1420, 812), Vector2(1560, 798), Vector2(1700, 816),
		Vector2(1860, 802), Vector2(2000, 820), Vector2(2120, 808), Vector2(2260, 816)], main_w, dirt, 14.0)
	# west road: plaza -> market -> graveyard lane -> graveyard gate (500,624)
	base.band([Vector2(990, 800), Vector2(840, 806), Vector2(700, 796), Vector2(560, 802),
		Vector2(462, 796), Vector2(450, 720), Vector2(448, 600)], lane_w, dirt, 10.0)
	# south road: plaza -> cottages -> terminus well (1120,1445)
	base.band([Vector2(1120, 910), Vector2(1112, 1050), Vector2(1128, 1200), Vector2(1116, 1330),
		Vector2(1120, 1440)], lane_w, dirt, 10.0)
	# farm lane: south road -> farmhouse -> barn
	base.band([Vector2(1120, 1152), Vector2(1300, 1146), Vector2(1480, 1158), Vector2(1640, 1150),
		Vector2(1800, 1162)], 30.0, dirt, 9.0)
	# east ring: main street -> farm lane
	base.band([Vector2(1440, 820), Vector2(1448, 980), Vector2(1436, 1152)], 28.0, dirt, 8.0)
	# market lane: west road -> cart -> cottage-back lane -> pond bank
	base.band([Vector2(800, 812), Vector2(806, 1000), Vector2(796, 1180), Vector2(800, 1300),
		Vector2(740, 1320), Vector2(690, 1332)], 28.0, dirt, 8.0)
	base.band([Vector2(800, 1280), Vector2(950, 1276), Vector2(1100, 1282)], 26.0, dirt, 8.0)
	# graveyard: worn path from the gate to the hooded statue
	base.band([Vector2(500, 600), Vector2(482, 500), Vector2(454, 390)], 20.0, dirt, 6.0)

	# --- YARDS: trampled earth where people work and stand (rule 4: story
	# clusters own their ground; nothing floats on lawn).
	base.ellipse(Vector2(1545, 862), 100.0, 46.0, dirt, 12.0)      # smithy work yard (forge + anvil)
	base.ellipse(Vector2(812, 802), 64.0, 28.0, dirt, 8.0)         # market stall (orange)
	base.ellipse(Vector2(868, 932), 64.0, 28.0, dirt, 8.0)         # market stall (green)
	base.ellipse(Vector2(778, 1022), 46.0, 22.0, dirt, 6.0)        # the cart
	base.ellipse(Vector2(700, 728), 46.0, 20.0, dirt, 6.0)         # merchant house door
	base.ellipse(Vector2(660, 978), 46.0, 20.0, dirt, 6.0)         # merchant house 2 door
	base.ellipse(Vector2(980, 1248), 46.0, 20.0, dirt, 6.0)        # cottage door
	base.ellipse(Vector2(1290, 1268), 46.0, 20.0, dirt, 6.0)       # cottage door
	base.ellipse(Vector2(1620, 1278), 52.0, 22.0, dirt, 6.0)       # farmhouse door
	base.ellipse(Vector2(1830, 1162), 64.0, 26.0, dirt, 8.0)       # barn mouth
	base.ellipse(Vector2(1700, 1276), 60.0, 24.0, dirt, 8.0)       # hay-strewn yard
	base.ellipse(Vector2(1200, 1122), 40.0, 20.0, dirt, 6.0)       # cottage well
	base.ellipse(Vector2(1120, 1448), 58.0, 30.0, dirt, 8.0)       # terminus well
	base.ellipse(Vector2(330, 420), 36.0, 24.0, dirt, 8.0)         # graveyard: bare patches
	base.ellipse(Vector2(620, 560), 28.0, 14.0, dirt, 5.0)         # under the wolf statue
	# POLISH 2026-09 clusters (see _polish_2026_09)
	base.ellipse(Vector2(1120, 255), 110.0, 46.0, dirt, 14.0)      # woodcutter yard behind the inn
	base.ellipse(Vector2(1980, 242), 60.0, 34.0, dirt, 8.0)        # travellers' camp NE
	base.ellipse(Vector2(1985, 1240), 60.0, 26.0, dirt, 8.0)       # farm cart east of the barn
	base.ellipse(Vector2(1664, 300), 84.0, 48.0, dirt, 8.0)        # hay paddock (fenced)
	base.ellipse(Vector2(1985, 745), 40.0, 18.0, dirt, 5.0)        # roadside saint
	base.ellipse(Vector2(760, 262), 60.0, 30.0, dirt, 8.0)         # old well ring north of the graveyard
	base.ellipse(Vector2(340, 1236), 58.0, 30.0, dirt, 8.0)        # wood-gatherer's clearing

	# --- SOIL: the fenced kitchen garden and the farm field
	base.rect_px(Rect2(864, 1344, 128, 64), soil)
	base.rect_px(Rect2(1408, 1312, 352, 64), soil)

	# --- POND: shallows ring then open water (sheet pairs Grass<->Shallows<->Water)
	base.ellipse(POND_CENTER, 150.0, 84.0, shallows, 8.0)
	base.ellipse(POND_CENTER, 100.0, 44.0, water, 4.0)

	# --- CITY (RAVEN HOLLOW CITY S1): canals, river, quays, cobbled streets and squares
	TownCity.paint_masks(base, top, top2)

	# --- COBBLE PLAZA (overlay so the cobble edge lands on the dirt lanes)
	top.ellipse(Vector2(1120, 800), 180.0, 128.0, cobble, 14.0)
	top.rect_px(Rect2(1088, 640, 64, 64), cobble)   # inn forecourt link
	top.ellipse(Vector2(1548, 864), 74.0, 40.0, cobble, 8.0)   # forge work floor
	top.ellipse(Vector2(448, 344), 28.0, 14.0, cobble, 4.0)    # graveyard saint plinth

	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = TerrainPainter.make_tileset(false)
	layer.y_sort_enabled = false
	layer.z_index = -10
	layer.self_modulate = GROUND_TINT   # v7: children (the overlays) tint themselves
	var painted: Dictionary = TerrainPainter.paint(layer, base, rng3)
	var over := TileMapLayer.new()
	over.name = "GroundOverlay"
	over.tile_set = TerrainPainter.make_tileset(true)
	over.y_sort_enabled = false
	over.z_index = 0   # relative to the base layer: same z, drawn after it
	var painted2: Dictionary = TerrainPainter.paint(over, top, rng3, true)
	layer.add_child(_city_earth(layer, painted))   # v8: desaturated city earth
	layer.add_child(TownCity.ground_wash())   # v7: under the overlays, above the base tiles
	over.modulate = GROUND_TINT   # the village plaza/forge floor stay byte-identical
	layer.add_child(over)
	_split_city_overlay(over, layer)
	# v8: ACCENT paving (a second keyed overlay): brown setts for the quay, the
	# keep courtyard and the ring around the fountain, so the city has three
	# paved materials instead of one grey for everything.
	var over2 := TileMapLayer.new()
	over2.name = "GroundOverlayCity2"
	over2.tile_set = TerrainPainter.make_tileset(true, true)
	over2.y_sort_enabled = false
	over2.z_index = 0
	over2.modulate = Color(0.98, 0.97, 0.96)   # brown setts at full value; no shader (2D shader writes come back gamma-squared here)

	var painted3: Dictionary = TerrainPainter.paint(over2, top2, rng3, true)
	layer.add_child(over2)
	for c3v: Variant in painted3:
		path_cells[c3v] = true
	for c: Variant in painted:
		path_cells[c] = true
	for c: Variant in painted2:
		path_cells[c] = true

	# The pond is not walkable: one convex bank collider on the world layer.
	var body := StaticBody2D.new()
	body.name = "PondBank"
	body.position = POND_CENTER
	body.collision_layer = 1
	body.collision_mask = 0
	var cs := CollisionShape2D.new()
	var poly := ConvexPolygonShape2D.new()
	var pts := PackedVector2Array()
	for i in range(16):
		var a: float = TAU * float(i) / 16.0
		pts.append(Vector2(cos(a) * 124.0, sin(a) * 68.0))
	poly.points = pts
	cs.shape = poly
	body.add_child(cs)
	layer.add_child(body)
	return layer


# ----------------------------------------------------------- POLISH 2026-09 ----

## Final-polish dressing for Raven Hollow. Rules: ONE kit (Szadi props on
## Szadi houses, Cainos stone, LPC fences/graves/lanterns, LPC crops+reeds),
## every prop OWNED by a building or a use, clusters not confetti (Bible 4/7/27),
## footprints checked by TownAudit (RH_PROPAUDIT=1) — nothing stands in anything.
static func _polish_2026_09(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	# --- cottage yards: rain barrel under the eave, bench by the door, wood, ivy
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", Vector2(930, 1226), 3.0))      # house_01 barrel
	props.add_child(_sprite(PROPS + "cainos_prop_04.png", Vector2(962, 1248), 3.0))     # house_01 bench
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1080, 1232), 3.0))     # house_01 woodpile
	_decal(decals, PROPS + "szadi_prop_03.png", Vector2(1020, 1196))
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1240, 1252), 3.0))     # house_05 woodpile
	_decal(decals, PROPS + "szadi_prop_04.png", Vector2(1246, 1214))
	props.add_child(_sprite(TOWN_KIT + "szadi_cloth_line.png", Vector2(1092, 1164), 4.0))  # washing line
	_decal(decals, PROPS + "szadi_prop_05.png", Vector2(640, 682))                      # merchant house ivy
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", Vector2(604, 706), 3.0))       # merchant barrel
	_decal(decals, PROPS + "szadi_prop_03.png", Vector2(586, 935))

	# --- farm field: fence with the yard open toward the farmhouse, crop rows
	var fx0: int = 43
	var fx1: int = 55
	var fy0: int = 40
	var fy1: int = 43
	for tx in range(fx0, fx1 + 1):
		if tx >= 48 and tx <= 51:
			pass   # yard gap in front of the farmhouse door
		elif tx == fx0:
			props.add_child(_fence_tile(F_TL, tx, fy0))
		elif tx == fx1:
			props.add_child(_fence_tile(F_TR, tx, fy0))
		else:
			props.add_child(_fence_tile(F_T, tx, fy0))
		var bot_rect: Rect2 = F_B
		if tx == fx0:
			bot_rect = F_BL
		elif tx == fx1:
			bot_rect = F_BR
		props.add_child(_fence_tile(bot_rect, tx, fy1))
	for ty in range(fy0 + 1, fy1):
		props.add_child(_fence_tile(F_L, fx0, ty))
		props.add_child(_fence_tile(F_R, fx1, ty))
	var rows: Array = [
		[1336.0, ["crop_corn", "crop_corn", "crop_corn", "crop_corn", "crop_corn", "crop_corn", "crop_corn", "crop_corn", "sprout_corn", "sprout_corn", "sprout_corn"]],
		[1368.0, ["crop_cabbage", "crop_lettuce", "crop_cabbage", "crop_lettuce", "crop_cabbage", "crop_lettuce", "crop_cabbage", "crop_lettuce", "sprout_cabbage", "sprout_lettuce", "sprout_cabbage"]],
	]
	for row: Variant in rows:
		var ry: float = row[0]
		var names: Array = row[1]
		for i in range(names.size()):
			var cs := _sprite(TOWN_KIT + str(names[i]) + ".png", Vector2(1428.0 + 32.0 * float(i), ry), 1.0)
			cs.modulate = Color(0.92, 0.90, 0.84)
			props.add_child(cs)

	# --- kitchen garden: lettuce/carrots on the mounds, tomatoes and cabbages behind
	for i in range(4):
		var gx: float = 880.0 + 32.0 * float(i)
		props.add_child(_sprite(TOWN_KIT + ("sprout_cabbage" if i % 2 == 0 else "sprout_pepper") + ".png", Vector2(gx, 1360.0), 1.0))
		props.add_child(_sprite(TOWN_KIT + ("crop_lettuce" if i % 2 == 0 else "crop_carrot") + ".png", Vector2(gx, 1388.0), 1.0))

	# --- pond bank: reeds on the shallows edge, rocks, a bucket where the path ends
	for rp: Vector2 in [Vector2(470, 1292), Vector2(650, 1290), Vector2(424, 1352), Vector2(698, 1362)]:
		var reed := _sprite(TOWN_KIT + ("reed_a" if int(rp.x) % 2 == 0 else "reed_b") + ".png", rp, 4.0)
		reed.modulate = Color(0.84, 0.86, 0.78)
		props.add_child(reed)
	props.add_child(_sprite(PROPS + "cainos_prop_37.png", Vector2(636, 1288), 2.0))
	props.add_child(_sprite(PROPS + "cainos_prop_38.png", Vector2(612, 1250), 2.0))
	props.add_child(_sprite(PROPS + "cainos_prop_39.png", Vector2(446, 1330), 2.0))
	props.add_child(_sprite(PROPS + "szadi_prop_10.png", Vector2(704, 1296), 2.0))

	# --- woodcutter's yard behind the inn: stump, saw-horse, log piles, crate
	props.add_child(_sprite(PROPS + "szadi_prop_18.png", Vector2(1104, 246), 3.0))
	_decal(decals, PROPS + "szadi_prop_01.png", Vector2(1150, 268))
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1050, 250), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_23.png", Vector2(1176, 240), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_25.png", Vector2(1120, 286), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", Vector2(1200, 272), 3.0))
	props.add_child(_circle_collider(Vector2(1104, 246), 8.0, Vector2(0, -4)))

	# --- hay paddock NE: fenced, gap on the south side, bales inside
	var px0: int = 49
	var px1: int = 54
	var py0: int = 7
	var py1: int = 11
	for tx in range(px0, px1 + 1):
		var t_rect: Rect2 = F_T
		if tx == px0:
			t_rect = F_TL
		elif tx == px1:
			t_rect = F_TR
		props.add_child(_fence_tile(t_rect, tx, py0))
		if tx >= 51 and tx <= 52:
			continue
		var b_rect: Rect2 = F_B
		if tx == px0:
			b_rect = F_BL
		elif tx == px1:
			b_rect = F_BR
		props.add_child(_fence_tile(b_rect, tx, py1))
	for ty in range(py0 + 1, py1):
		props.add_child(_fence_tile(F_L, px0, ty))
		props.add_child(_fence_tile(F_R, px1, ty))
	props.add_child(_sprite(PROPS + "szadi_prop_21.png", Vector2(1618, 300), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_21.png", Vector2(1700, 320), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_21.png", Vector2(1662, 270), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_24.png", Vector2(1724, 288), 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_12.png", Vector2(1600, 332), 3.0))     # trough
	props.add_child(_atlas_sprite(R_CART, Vector2(1664, 404), 5.0))                     # hay cart at the gate
	props.add_child(_rect_collider(Vector2(1664, 404), Vector2(52, 18), Vector2(0, -10)))
	props.add_child(_sprite(PROPS + "szadi_prop_21.png", Vector2(1714, 398), 3.0))
	# travellers' camp in the NE corner: fire, log seats, pack — a reason to walk there
	var camp_fire := _anim_sprite(FIRE_FRAMES, 8.0, Vector2(1980, 236), 4.0)
	props.add_child(camp_fire)
	props.add_child(_circle_collider(Vector2(1980, 236), 9.0, Vector2(0, -5)))
	lights.add_child(_light(Vector2(1980, 220), Color(1.0, 0.62, 0.32), 0.9, 105.0))
	props.add_child(_sprite(PROPS + "szadi_prop_18.png", Vector2(1946, 258), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_25.png", Vector2(2014, 262), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_24.png", Vector2(2018, 230), 3.0))
	# the farm's cart east of the barn
	props.add_child(_atlas_sprite(R_CART, Vector2(1990, 1236), 5.0))
	props.add_child(_rect_collider(Vector2(1990, 1236), Vector2(52, 18), Vector2(0, -10)))
	props.add_child(_sprite(PROPS + "szadi_prop_21.png", Vector2(1948, 1256), 3.0))

	# --- roadside saint by the east road: statue on a slab, lantern, bench
	_decal(decals, PROPS + "cainos_prop_00.png", Vector2(1985, 740))
	props.add_child(_sprite(PROPS + "cainos_prop_06.png", Vector2(1985, 736), 3.0))
	props.add_child(_rect_collider(Vector2(1985, 736), Vector2(22, 10), Vector2(0, -5)))
	props.add_child(_lamp_post(Vector2(2024, 748)))
	props.add_child(_circle_collider(Vector2(2024, 748), 4.0, Vector2(0, -2)))
	lights.add_child(_light(Vector2(2024, 686), Color(1.0, 0.78, 0.45), 0.6, 75.0))
	props.add_child(_sprite(PROPS + "cainos_prop_04.png", Vector2(1944, 752), 3.0))

	# --- old well ring north of the graveyard (curiosity site): ring, rocks, dead oak
	props.add_child(_sprite(PROPS + "cainos_prop_32.png", Vector2(760, 262), 3.0))
	props.add_child(_rect_collider(Vector2(760, 262), Vector2(44, 14), Vector2(0, -7)))
	props.add_child(_sprite(PROPS + "cainos_prop_38.png", Vector2(716, 288), 2.0))
	props.add_child(_sprite(PROPS + "cainos_prop_39.png", Vector2(808, 280), 2.0))
	props.add_child(_sprite("res://assets/art/world/freekit/trees/tree_dead_oak.png", Vector2(700, 218), 8.0))
	props.add_child(_circle_collider(Vector2(700, 218), 6.0, Vector2(0, -3)))

	# --- copses on the north and north-east lawns, boulders behind the smithy
	for cp: Array in [[Vector2(1380, 330), 0], [Vector2(1442, 392), 1], [Vector2(1502, 336), 2],
			[Vector2(1900, 418), 1], [Vector2(1962, 482), 0], [Vector2(2010, 420), 2]]:
		_tree(props, int(cp[1]), cp[0])
	for bp: Array in [[Vector2(1412, 424), 4], [Vector2(1470, 300), 6], [Vector2(1930, 510), 5], [Vector2(2040, 470), 3]]:
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % int(bp[1]), bp[0], 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_33.png", Vector2(1760, 470), 3.0))
	props.add_child(_rect_collider(Vector2(1760, 470), Vector2(40, 12), Vector2(0, -6)))
	props.add_child(_sprite(PROPS + "cainos_prop_38.png", Vector2(1798, 494), 2.0))

	# --- chimney smoke: the inn (two stacks) and the smithy (CPUParticles, cheap)
	for cp: Vector2 in [Vector2(1013, 340), Vector2(1225, 340), Vector2(1614, 585)]:
		props.add_child(_chimney_smoke(cp))

	# --- warm door lights so every house reads inhabited at night
	for dp: Vector2 in [Vector2(980, 1182), Vector2(1290, 1202), Vector2(700, 662), Vector2(660, 912), Vector2(1620, 1212)]:
		lights.add_child(_light(dp, Color(1.0, 0.74, 0.42), 0.35, 55.0))


static func _chimney_smoke(pos: Vector2) -> CPUParticles2D:
	var smoke := CPUParticles2D.new()
	smoke.position = pos
	smoke.amount = 14
	smoke.lifetime = 3.8
	smoke.preprocess = 3.5
	smoke.direction = Vector2(0.18, -1.0)
	smoke.spread = 11.0
	smoke.gravity = Vector2(5.0, -12.0)
	smoke.initial_velocity_min = 8.0
	smoke.initial_velocity_max = 14.0
	smoke.scale_amount_min = 0.6
	smoke.scale_amount_max = 1.3
	var puff := GradientTexture2D.new()
	puff.width = 16
	puff.height = 16
	puff.fill = GradientTexture2D.FILL_RADIAL
	puff.fill_from = Vector2(0.5, 0.5)
	puff.fill_to = Vector2(0.5, 0.0)
	var pg := Gradient.new()
	pg.set_color(0, Color(1, 1, 1, 1))
	pg.set_color(1, Color(1, 1, 1, 0))
	puff.gradient = pg
	smoke.texture = puff
	smoke.color = Color(0.80, 0.78, 0.76, 0.5)
	var g := Gradient.new()
	g.set_color(0, Color(0.85, 0.82, 0.80, 0.55))
	g.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	smoke.color_ramp = g
	smoke.z_index = 4
	return smoke


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

	# Crate pair tucked into the NE corner beside the lamp post (market
	# spillover encroaching on the pavement edge, deliberately walkable-around).
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", Vector2(1266, 736), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_31.png", Vector2(1246, 750), 3.0))


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

	# Bench by the entrance, ivy at the corner, and a barrel pair hugging the
	# west (kitchen) wing: one dominant cask with a small keg offset beside it.
	props.add_child(_sprite(PROPS + "cainos_prop_04.png", Vector2(1322, 650), 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_18.png", Vector2(990, 632), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", Vector2(966, 628), 3.0))
	_decal(decals, PROPS + "szadi_prop_00.png", Vector2(1300, 585))
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1298, 628), 3.0))


static func _smithy(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	props.add_child(_place_building("house_00.png", Vector2(1560, 750)))

	# Forge work floor: cobble is painted by _build_ground_painted (overlay);
	# anvil and fire pit sit on it.
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", Vector2(1486, 898), 2.0))
	props.add_child(_sprite(PROPS + "szadi_prop_18.png", Vector2(1578, 880), 2.0))
	props.add_child(_atlas_sprite(R_ANVIL, Vector2(1585, 855), 4.0))
	props.add_child(_circle_collider(Vector2(1585, 855), 9.0, Vector2(0, -6)))
	var fire := _anim_sprite(FIRE_FRAMES, 8.0, Vector2(1508, 855), 4.0)
	props.add_child(fire)
	props.add_child(_circle_collider(Vector2(1508, 855), 9.0, Vector2(0, -5)))
	lights.add_child(_light(Vector2(1508, 838), Color(1.0, 0.6, 0.3), 1.1, 120.0))

	# Fuel corner along the east wall: crate stack up top, then the woodpile —
	# stacked bundle dominant, two loose logs offset around it (gathered here
	# from the plaza/market/farm where they used to float).
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1665, 810), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_10.png", Vector2(1652, 872), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_18.png", Vector2(1680, 886), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_25.png", Vector2(1630, 888), 3.0))
	# Brick stock on the grass at the work floor's west edge, by the fire.
	props.add_child(_sprite(PROPS + "szadi_prop_19.png", Vector2(1455, 862), 3.0))


static func _market(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	props.add_child(_place_building("house_02.png", Vector2(700, 690)))
	props.add_child(_place_building("house_06.png", Vector2(660, 940)))

	props.add_child(_market_stall(Vector2(812, 772), R_DRAPE_ORANGE))
	props.add_child(_rect_collider(Vector2(812, 772), Vector2(90, 22), Vector2(0, -14)))
	props.add_child(_market_stall(Vector2(868, 902), R_DRAPE_GREEN))
	props.add_child(_rect_collider(Vector2(868, 902), Vector2(90, 22), Vector2(0, -14)))

	# Goods hugging the stall counters + a hand cart parked off the lane.
	props.add_child(_sprite(PROPS + "szadi_prop_15.png", Vector2(756, 838), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_24.png", Vector2(922, 908), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_31.png", Vector2(758, 762), 3.0))
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

	# Grain sack at the west cottage's SE corner; barrel + pot pair tucked
	# against the east cottage's SE corner.
	props.add_child(_sprite(PROPS + "szadi_prop_26.png", Vector2(1046, 1222), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", Vector2(1362, 1242), 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_23.png", Vector2(1338, 1246), 3.0))
	_decal(decals, PROPS + "szadi_prop_00.png", Vector2(915, 1150))


static func _farmstead(props: Node2D, decals: Node2D, rng: RandomNumberGenerator) -> void:
	props.add_child(_place_building("house_03.png", Vector2(1620, 1240)))
	props.add_child(_place_building("house_07.png", Vector2(1830, 1120)))

	# Everything stacked against walls the way a farmhand would leave it:
	# hay heaps flank the barn door, the feed trough sits past the SE corner,
	# and the crates hug the farmhouse front. (Logs moved to the smithy pile.)
	props.add_child(_sprite(PROPS + "szadi_prop_14.png", Vector2(1672, 1266), 4.0))
	props.add_child(_circle_collider(Vector2(1672, 1266), 14.0, Vector2(0, -9)))
	props.add_child(_sprite(PROPS + "szadi_prop_29.png", Vector2(1566, 1262), 4.0))
	props.add_child(_circle_collider(Vector2(1566, 1262), 14.0, Vector2(0, -9)))
	props.add_child(_sprite(PROPS + "szadi_prop_12.png", Vector2(1734, 1250), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", Vector2(1900, 1145), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", Vector2(1872, 1150), 3.0))
	# Loose hay bales dropped where the work happens: beside each hay heap
	# and one by the farmhouse door. (rng draw kept so later streams are
	# byte-identical to the pre-polish build; it only jitters the bale now.)
	var hay_bits: Array = [Vector2(1524, 1270), Vector2(1700, 1252), Vector2(1792, 1148)]
	for p: Vector2 in hay_bits:
		var jitter: int = rng.randi_range(0, 1)
		props.add_child(_sprite(PROPS + "szadi_prop_21.png", p + Vector2(float(jitter) * 3.0, 0.0), 3.0))
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
	props.add_child(_atlas_sprite(R_STATUE_WOLF, Vector2(620, 556), 4.0))
	props.add_child(_rect_collider(Vector2(620, 556), Vector2(20, 10), Vector2(0, -5)))

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
	for p: Vector2 in [Vector2(378, 486), Vector2(584, 326), Vector2(292, 336)]:
		_decal(decals, PROPS + "szadi_prop_00.png", p)

	# A lantern by the gate; a worn stone patch outside it.
	# Lantern beside the gate mouth, clear of the fence rail (sitting #1).
	var gate := Vector2(500, 624)
	props.add_child(_lamp_post(gate))
	props.add_child(_circle_collider(gate, 4.0, Vector2(0, -2)))
	lights.add_child(_light(gate + Vector2(0, -62), Color(1.0, 0.78, 0.45), 0.7, 85.0))
	# Context so the worn patch reads as a ruined threshold, not an orphan tile.
	props.add_child(_sprite(PROPS + "cainos_prop_38.png", Vector2(486, 660), 2.0))

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

		# POLISH 2026-09: the merchant house (house_02) stands over tiles 18-20 of
		# the south rail and tiles 12-16 of the east rail; the fence now stops at
		# the house instead of running under its roof and lean-to.
		if tx > 17:
			continue
		var bot_rect: Rect2 = F_B
		if tx == GY_TX0:
			bot_rect = F_BL
		elif tx == 17:
			bot_rect = F_BR
		elif tx == 13 or tx == 14:
			bot_rect = F_POST  # open gate posts
		props.add_child(_fence_tile(bot_rect, tx, GY_TY1))

	for ty in range(GY_TY0 + 1, GY_TY1):
		props.add_child(_fence_tile(F_L, GY_TX0, ty))
		if ty <= 11:
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
		if p.x < 130.0 or p.y < 150.0:
			continue   # CITY: the wall bands stand there now
		if gy_exclude.has_point(p):
			continue
		if CLEAR_TERMINUS.has_point(p) or CLEAR_GARDEN.has_point(p) or CLEAR_POND.has_point(p):
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
	for p: Vector2 in [Vector2(770, 555), Vector2(392, 905), Vector2(1368, 1080), Vector2(735, 1370)]:
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
	# CITY: the ring is the HOLLOW's ring (old 70x50 extent). West + north rows are
	# placed; the east + south rows are consumed (identical rng2 draws) but skipped —
	# those edges now open into the Trade Square and the Fields.
	var w := float(HOLLOW_TILES_W * TILE)
	var h := float(HOLLOW_TILES_H * TILE)
	var x: float = 44.0
	while x < w - 40.0:
		var jx: float = x + rng2.randf_range(-14.0, 14.0)
		_forest_tree(props, rng2, Vector2(jx, rng2.randf_range(26.0, 46.0)), false, path_cells, true)
		_forest_tree(props, rng2, Vector2(jx + 38.0, rng2.randf_range(74.0, 104.0)), true, path_cells, true)
		_forest_tree(props, rng2, Vector2(jx, h - rng2.randf_range(4.0, 24.0)), false, path_cells, true)
		_forest_tree(props, rng2, Vector2(jx + 38.0, h - rng2.randf_range(52.0, 82.0)), true, path_cells, true)
		x += 76.0 + rng2.randf_range(-10.0, 10.0)
	var y: float = 140.0
	while y < h - 130.0:
		_forest_tree(props, rng2, Vector2(rng2.randf_range(16.0, 38.0), y), false, path_cells, true)
		_forest_tree(props, rng2, Vector2(rng2.randf_range(64.0, 96.0), y + 40.0), true, path_cells, true)
		_forest_tree(props, rng2, Vector2(w - rng2.randf_range(16.0, 38.0), y), false, path_cells, true)
		_forest_tree(props, rng2, Vector2(w - rng2.randf_range(64.0, 96.0), y + 40.0), true, path_cells, true)
		y += 82.0 + rng2.randf_range(-10.0, 10.0)


static func _forest_tree(props: Node2D, rng2: RandomNumberGenerator, pos: Vector2, collide: bool, path_cells: Dictionary, skip: bool = false) -> void:
	var cell := Vector2i(int(pos.x / 32.0), int(pos.y / 32.0))
	if path_cells.has(cell):
		return
	# NOTE: R_BIG_TREE has a clock baked into the trunk (graveyard flavor only)
	# so the forest mixes leafy Cainos trees with the clean gnarled sapling.
	# Consume the same rng2 draws whether or not the spot is rejected below,
	# so the rest of the border forest keeps its exact layout.
	var roll: float = rng2.randf()
	var variant: int = rng2.randi_range(0, 2) if roll < 0.94 else -1
	# Reject inside the kept-open clearings AFTER consuming the rng2 draws above,
	# so the rest of the border forest stays byte-identical. CLEAR_GATE keeps the
	# east-gate mouth open for GateBuilder (contract §14).
	if CLEAR_TERMINUS.has_point(pos) or CLEAR_GARDEN.has_point(pos) or CLEAR_GATE.has_point(pos):
		return
	if skip:
		return   # CITY: draws consumed, tree not placed (edge opens into the city)
	if variant >= 0:
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % variant, pos, 10.0))
	else:
		props.add_child(_atlas_sprite(R_SMALL_TREE, pos, 4.0))
	if collide:
		props.add_child(_circle_collider(pos, 7.0, Vector2(0, -4)))


static func _orchard(props: Node2D) -> void:
	# Small orchard grid behind (south of) the east cottage, west of the ring.
	# Leafy plant_02 trees (the gnarled atlas trees read as a dead grove here).
	for ix in range(2):
		for iy in range(2):
			var p := Vector2(
				1230.0 + 92.0 * float(ix) + (16.0 if iy == 1 else 0.0),
				1338.0 + 80.0 * float(iy))
			props.add_child(_sprite(PLANTS + "plant_02.png", p, 10.0))
			props.add_child(_circle_collider(p, 5.0, Vector2(0, -3)))
	# picking gear under the trees: ladder + two baskets
	props.add_child(_sprite(PROPS + "szadi_prop_16.png", Vector2(1238, 1404), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_24.png", Vector2(1226, 1450), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_26.png", Vector2(1302, 1454), 3.0))


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
		["cainos_prop_17.png", Vector2(1076, 1198)],  # south road x farm lane
		# (was cainos_prop_28 — a grave cross; that sprite belongs in the yard)
		["cainos_prop_17.png", Vector2(466, 728)],    # graveyard lane corner
	]
	for s: Array in signposts:
		props.add_child(_sprite(PROPS + String(s[0]), s[1], 2.0))
		props.add_child(_circle_collider(s[1], 3.0, Vector2(0, -2)))

	# Lamp posts along the main roads (warm, sparse).
	var lamps: Array = [
		Vector2(1350, 752), Vector2(1072, 1000),
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
	# Pot pair at the shop's front-west corner (the old lone plaza pots,
	# rehomed against a wall where a shopkeeper would stand them).
	props.add_child(_sprite(PROPS + "cainos_prop_31.png", Vector2(620, 962), 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_27.png", Vector2(596, 966), 3.0))

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
		["cainos_prop_34.png", Vector2(492, 812)],
		["cainos_prop_36.png", Vector2(1196, 1206)],  # grass shoulder south of the farm lane, by the lamp
		["cainos_prop_38.png", Vector2(1484, 1190)],   # moved off the bush (audit)
		["cainos_prop_40.png", Vector2(2118, 1246)],  # outcrop by the east lane (moved off a tree, city pass)
		["cainos_prop_35.png", Vector2(870, 1050)],
	]
	for r: Array in rocks:
		props.add_child(_sprite(PROPS + String(r[0]), r[1], 2.0))


static func _south_terminus(props: Node2D, lights: Node2D) -> void:
	# The south road ends at a second, larger village well with a bench.
	props.add_child(_sprite(PROPS + "szadi_prop_11.png", Vector2(1120, 1445), 4.0))
	props.add_child(_rect_collider(Vector2(1120, 1445), Vector2(44, 22), Vector2(0, -11)))
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
	# Unique-villager contract: each ambient villager also gets a palette from
	# the curated muted pools below (applied by npc.gd via palette_swap
	# ShaderMaterial). Outfit colorways are drawn WITHOUT replacement, so every
	# spawned (sheet, variant, palette) triple is unique; the named cast passes
	# no "palette" key at all (identity look), so no villager can shadow them.
	var outfits: Array = [
		{"a": Color("6b6b3a"), "b": Color("4a4a28")},  # olive
		{"a": Color("6e3030"), "b": Color("4c2020")},  # oxblood
		{"a": Color("6b4a2f"), "b": Color("4a3320")},  # umber
		{"a": Color("4e5a66"), "b": Color("37414a")},  # slate
		{"a": Color("55663f"), "b": Color("3b472c")},  # moss
		{"a": Color("3f3f43"), "b": Color("2b2b2e")},  # charcoal
		{"a": Color("8a7a58"), "b": Color("625640")},  # dun
		{"a": Color("46655f"), "b": Color("304742")},  # faded teal
		{"a": Color("5d3547"), "b": Color("402432")},  # wine
		{"a": Color("7a7a72"), "b": Color("565650")},  # ash
	]
	var hairs: Array = [
		Color("1d1a17"),  # black
		Color("3d2c1e"),  # dark brown
		Color("5a3a24"),  # chestnut
		Color("8a8578"),  # ash grey
		Color("d8d3c8"),  # white
		Color("58291f"),  # dark auburn
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
		var colorway: Dictionary = outfits.pop_at(rng2.randi_range(0, outfits.size() - 1))
		var hair: Color = hairs[rng2.randi_range(0, hairs.size() - 1)]
		var skin: int = rng2.randi_range(0, 3)
		var def := {
			"id": "villager_%d" % i,
			"display_name": String(row[0]),
			"sheet": "res://assets/art/characters/%s.png" % String(pick[0]),
			"variant": int(pick[1]),
			"pos": row[1],
			"wander_radius": rng2.randf_range(70.0, 150.0),
			"dialogue": [String(row[2])],
			"facing": "down",
			"palette": {
				"outfit_a": colorway["a"],
				"outfit_b": colorway["b"],
				"hair": hair,
				"skin": skin,
			},
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
	# POLISH 2026-09: Szadi thatch awning on its own poles (same pack as the
	# houses) replaces the LPC candy-stripe drape — one kit, one palette.
	# `drape` is kept in the signature so callers stay byte-identical.
	var roof := Sprite2D.new()
	roof.texture = load(TOWN_KIT + "szadi_awning.png")
	roof.centered = false
	var rs: Vector2 = roof.texture.get_size()
	roof.offset = Vector2(rs.x * -0.5, -rs.y)
	roof.position = Vector2(0, -14)   # pole feet just behind the counter line
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
	# Day/night registry (contract §8): every ambience light (lanterns, forge
	# glow, plaza/inn/graveyard/well lights) joins "world_lights" so DayNight
	# ramps its energy across the cycle. Pre-seed the base-energy meta with the
	# authored value so the ramp restores the hand-tuned look at 17:00 (scale
	# 1.0). Town lights are static — none run their own flicker tween, so no
	# light opts out via "dn_ignore".
	l.set_meta("dn_base_energy", energy)
	l.add_to_group("world_lights")
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


# ==================== RAVEN HOLLOW V2 (Fable, 2026-07-12) ====================
## The town rebuilt on the owner's generated library. Every district keeps its
## gameplay anchor (npc_spawns/stations above) and gets library dressing:
## props OWNED, clusters that tell one story, lights only where life burns.

const GENW := "res://assets/art/world/gen/"
const GEN2 := "res://assets/art/world/gen2/"
const CIVIC := "res://assets/art/world/civic/"


static func _kit(props: Node2D, path: String, pos: Vector2, skirt: float = 4.0,
		scale: float = 1.0, flip: bool = false) -> void:
	if not ResourceLoader.exists(path):
		return
	var spr := _sprite(path, pos, skirt)
	spr.scale = Vector2.ONE * scale
	spr.flip_h = flip
	props.add_child(spr)


static func _torch(props: Node2D, lights: Node2D, pos: Vector2) -> void:
	var tex_path := CIVIC + "torch_anim_strip.png"
	if not ResourceLoader.exists(tex_path):
		return
	var atex: Texture2D = load(tex_path)
	var fw: int = atex.get_width() / 4
	var sfr := SpriteFrames.new()
	sfr.set_animation_speed("default", 8.0)
	for fi in range(4):
		var at := AtlasTexture.new()
		at.atlas = atex
		at.region = Rect2(fi * fw, 0, fw, atex.get_height())
		sfr.add_frame("default", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sfr
	spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	spr.position = pos
	spr.offset = Vector2(0, -atex.get_height() * 0.5 + 4)
	spr.y_sort_enabled = true
	spr.play("default")
	props.add_child(spr)
	lights.add_child(_light(pos + Vector2(0, -14), Color(1.0, 0.62, 0.28), 0.55, 60.0))


## Plaza: the well at the heart, marble watchers, lantern ring, benches.
static func _plaza_v2(props: Node2D, decals: Node2D, lights: Node2D, _rng: RandomNumberGenerator) -> void:
	var c := Vector2(1120.0, 860.0)
	_kit(props, GENW + "village_well_1000.png", c, 6.0)
	_kit(props, CIVIC + "mc_statue_marble.png", c + Vector2(-92, -40), 4.0)
	_kit(props, CIVIC + "mc_statue_marble.png", c + Vector2(92, -40), 4.0, 1.0, true)
	_kit(props, CIVIC + "mc_urn.png", c + Vector2(-64, 44), 3.0)
	_kit(props, CIVIC + "mc_urn.png", c + Vector2(64, 44), 3.0, 1.0, true)
	_kit(props, GEN2 + "f_bench.png", c + Vector2(-120, 20), 3.0)
	_kit(props, GEN2 + "f_bench.png", c + Vector2(120, 20), 3.0, 1.0, true)
	_kit(props, GENW + "signpost_1000.png", c + Vector2(30, 78), 3.0)
	for off: Vector2 in [Vector2(-140, -76), Vector2(140, -76), Vector2(-140, 84), Vector2(140, 84)]:
		_kit(props, GENW + "lantern_post_1000.png", c + off, 3.0)
		lights.add_child(_light(c + off + Vector2(0, -26), Color(1.0, 0.72, 0.38), 0.5, 70.0))


## The Ember Hearth: guild-scale inn, working yard, the hearth station fire.
static func _inn_v2(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var door := Vector2(1120.0, 560.0)
	_kit(props, CIVIC + "szfl_house_03.png", door + Vector2(0, -36), 8.0, 0.72)
	# hearth station fire (station at 1120,620)
	_kit(props, GEN2 + "l_cauldron.png", Vector2(1120, 616), 3.0)
	_kit(props, GENW + "iron_brazier_1000.png", Vector2(1152, 622), 3.0)
	lights.add_child(_light(Vector2(1136, 606), Color(1.0, 0.58, 0.25), 0.75, 85.0))
	# owned yard: kegs to the door, cart at the lane, wood for the fires
	_kit(props, GENW + "barrel_stack_1000.png", door + Vector2(-86, 46), 3.0)
	_kit(props, GEN2 + "f_barrel.png", door + Vector2(-56, 58), 3.0)
	_kit(props, GENW + "crate_stack_1000_0.png", door + Vector2(84, 50), 3.0)
	_kit(props, GENW + "hand_cart_1000.png", door + Vector2(148, 66), 4.0)
	_kit(props, GENW + "woodpile_1000.png", door + Vector2(-140, 60), 3.0)
	_kit(props, GENW + "water_trough_1000_0.png", door + Vector2(52, 84), 3.0)
	_kit(props, GEN2 + "f_jug.png", door + Vector2(-30, 76), 2.0)
	_torch(props, lights, door + Vector2(-64, 8))
	_torch(props, lights, door + Vector2(64, 8))


## Goran's smithy: red stone house, the forge that feeds the anvil station.
static func _smithy_v2(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var anchor := Vector2(1515.0, 760.0)
	_kit(props, GEN2 + "b_house_red.png", anchor, 6.0)
	_kit(props, GENW + "blacksmith_forge_1000.png", Vector2(1585, 848), 5.0)
	_kit(props, GENW + "anvil_stump_1000.png", Vector2(1552, 878), 3.0)
	lights.add_child(_light(Vector2(1585, 838), Color(1.0, 0.5, 0.2), 0.8, 90.0))
	_kit(props, GEN2 + "ore_cart.png", anchor + Vector2(96, 84), 4.0)
	_kit(props, GEN2 + "cart_wheel.png", anchor + Vector2(-72, 96), 2.0)
	_kit(props, GENW + "woodpile_8919.png", anchor + Vector2(-104, 70), 3.0)
	_kit(props, GENW + "iron_brazier_8919.png", anchor + Vector2(58, 108), 3.0)
	lights.add_child(_light(anchor + Vector2(58, 96), Color(1.0, 0.6, 0.28), 0.4, 55.0))
	_kit(props, GENW + "stone_cairn_1000.png", anchor + Vector2(140, 40), 2.0)


## Market row: three stalls, produce, the merchant's clutter.
static func _market_v2(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var c := Vector2(843.0, 790.0)
	_kit(props, GENW + "market_stall_1000.png", c + Vector2(-70, 0), 5.0)
	_kit(props, GENW + "market_stall_8919.png", c + Vector2(40, -6), 5.0)
	_kit(props, GENW + "market_stall_16838.png", c + Vector2(150, 2), 5.0)
	_kit(props, GENW + "grain_sacks_1000.png", c + Vector2(-104, 52), 3.0)
	_kit(props, GEN2 + "wheelbarrow_produce.png", c + Vector2(-16, 58), 3.0)
	_kit(props, GENW + "crate_stack_8919_0.png", c + Vector2(86, 56), 3.0)
	_kit(props, GENW + "barrel_stack_8919.png", c + Vector2(178, 48), 3.0)
	_kit(props, GEN2 + "f_jug.png", c + Vector2(120, 66), 2.0)
	_kit(props, GENW + "hand_cart_8919.png", c + Vector2(-150, 70), 4.0, 1.0, true)
	_torch(props, lights, c + Vector2(-120, -18))
	_torch(props, lights, c + Vector2(200, -14))


## Cottage lanes: the three roof colourways + stone cottage, fenced yards.
static func _cottages_v2(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	var rows: Array = [
		[CIVIC + "szh_town_purple.png", Vector2(700, 1120), false],
		[CIVIC + "szh_town_slate.png", Vector2(905, 1165), true],
		[CIVIC + "szh_town_red.png", Vector2(1300, 1120), false],
		[GEN2 + "b_cottage_stone.png", Vector2(1495, 1165), true],
	]
	for row: Array in rows:
		_kit(props, str(row[0]), row[1] as Vector2, 6.0, 1.0, bool(row[2]))
	# owned yards
	_kit(props, GEN2 + "r_flower_box.png", Vector2(742, 1176), 2.0)
	_kit(props, GENW + "wooden_fence_1000.png", Vector2(648, 1176), 3.0)
	_kit(props, GENW + "wooden_fence_8919.png", Vector2(968, 1214), 3.0)
	_kit(props, GEN2 + "f_jug.png", Vector2(940, 1222), 2.0)
	_kit(props, GENW + "woodpile_1000.png", Vector2(1252, 1180), 3.0)
	_kit(props, GEN2 + "wheelbarrow.png", Vector2(1352, 1186), 3.0)
	_kit(props, GENW + "dead_bush_1000.png", Vector2(1540, 1222), 2.0)
	_kit(props, GEN2 + "d_lantern.png", Vector2(1075, 1150), 3.0)
	lights.add_child(_light(Vector2(1075, 1136), Color(1.0, 0.7, 0.36), 0.45, 60.0))


## Farmstead: green barn, hay, trough — Anica's ground (farmer 1565,1300).
static func _farmstead_v2(props: Node2D, decals: Node2D, _rng: RandomNumberGenerator) -> void:
	var c := Vector2(1620.0, 1250.0)
	_kit(props, GEN2 + "b_barn_green.png", c, 6.0)
	_kit(props, GENW + "hay_bale_1000.png", c + Vector2(-84, 62), 3.0)
	_kit(props, GENW + "hay_bale_1000.png", c + Vector2(-40, 84), 3.0)
	_kit(props, GENW + "water_trough_1000_0.png", c + Vector2(70, 70), 3.0)
	_kit(props, GENW + "grain_sacks_8919.png", c + Vector2(104, 52), 3.0)
	_kit(props, GEN2 + "wheelbarrow.png", c + Vector2(-130, 84), 3.0, 1.0, true)
	_kit(props, GENW + "wooden_fence_1000.png", c + Vector2(-160, 40), 3.0)
	_kit(props, GENW + "tree_stump_1000.png", c + Vector2(150, 100), 2.0)


## Graveyard NW: the chapel, ordered rows gone crooked, the wraith that
## watches, one open grave (canon: the grave out of line).
static func _graveyard_v2(props: Node2D, decals: Node2D, lights: Node2D, rng: RandomNumberGenerator) -> void:
	var c := Vector2(430.0, 420.0)
	_kit(props, GENW + "gothic_chapel_1000.png", c + Vector2(30, -80), 8.0)
	_torch(props, lights, c + Vector2(-16, -28))
	var stones: Array = [GENW + "grave_cross_1000.png", GENW + "gravestone_1000.png",
			GENW + "grave_cross_8919.png", GENW + "gravestone_8919.png"]
	for gy in range(3):
		for gx in range(4):
			var p := c + Vector2(-90 + gx * 52 + rng.randf_range(-7, 7), 60 + gy * 56 + rng.randf_range(-5, 5))
			_kit(props, str(stones[(gx + gy) % stones.size()]), p, 3.0)
	_kit(props, GEN2 + "coffin_open.png", c + Vector2(150, 92), 3.0)
	_kit(props, GEN2 + "wraith_statue.png", c + Vector2(-136, 34), 4.0)
	_kit(props, GEN2 + "candle_rock.png", c + Vector2(160, 148), 2.0)
	lights.add_child(_light(c + Vector2(160, 140), Color(1.0, 0.65, 0.3), 0.35, 45.0))
	_kit(props, GENW + "dead_bush_1000.png", c + Vector2(-60, 200), 2.0)
	_kit(props, GENW + "dead_bush_1000.png", c + Vector2(120, 196), 2.0, 1.0, true)


## Watchtowers hold the corners; wall stubs flank the east gate road.
static func _walls_v2(props: Node2D, lights: Node2D) -> void:
	_kit(props, GENW + "watchtower_1000.png", Vector2(180, 180), 6.0, 0.9)
	_kit(props, GENW + "watchtower_8919.png", Vector2(2060, 200), 6.0, 0.9)
	_kit(props, GENW + "watchtower_1000.png", Vector2(2040, 1400), 6.0, 0.9, true)
	_torch(props, lights, Vector2(2060, 260))
	_kit(props, GENW + "stone_wall_8919.png", Vector2(2170, 700), 4.0)
	_kit(props, GENW + "stone_wall_8919.png", Vector2(2170, 930), 4.0, 1.0, true)


## Story beats: the roadside shrine south, the crossroads cross, and what the
## crows found behind the smithy (never explained — the scene IS the sentence).
static func _vignettes_v2(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	_kit(props, GENW + "roadside_shrine_1000.png", Vector2(1080, 1420), 4.0)
	_kit(props, GEN2 + "d_candle_pot.png", Vector2(1108, 1438), 2.0)
	lights.add_child(_light(Vector2(1094, 1414), Color(1.0, 0.68, 0.32), 0.35, 50.0))
	_kit(props, GEN2 + "t_cross_post.png", Vector2(1560, 1010), 3.0)
	# behind the smithy: the pool, the skull, the chest nobody claims
	_decal(decals, GEN2 + "blood_pool.png", Vector2(1680, 700))
	_kit(props, GEN2 + "skull_small.png", Vector2(1706, 712), 2.0)
	_kit(props, GEN2 + "c_chest.png", Vector2(1730, 668), 3.0)
	_kit(props, GENW + "mossy_rock_1000.png", Vector2(1660, 736), 2.0)
