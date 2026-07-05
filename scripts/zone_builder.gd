class_name ZoneBuilder
## WORLD_PLAN.md engine — generic, data-driven builder for the 40-zone Draconia
## world. One builder, forty hand-authored zone defs (scripts/zone_defs.gd):
## every zone is constructed from its def's authored layout data — landmark
## anchors, road/river polylines, lore vignettes, creature spawn tables — over
## a biome-painted ground. "Hand-crafted" lives in the DATA (per-zone anchors
## authored against the lore bible), not in per-zone code.
##
## build_zone(parent, def) returns the TownBuilder/WildernessBuilder contract:
##   {player_spawn, npc_spawns, bounds, enemy_spawns, ambient_spawns}
## Deterministic per-zone: seeded RNG from the zone id hash.
##
## Biome palettes reference CURRENT in-repo assets as the base layer; packs
## downloaded by the acquisition workflow swap in per-biome tilesets by editing
## _PALETTES only (zone defs stay untouched).

const TILE: int = 32

const GRASS_SHEET := "res://assets/art/terrain/cainos_grass.png"
const STONE_SHEET := "res://assets/art/terrain/cainos_stone_ground.png"
const DECOR := "res://assets/art/decor/lpc_decorations.png"
const PROPS := "res://assets/art/props/"
const PLANTS := "res://assets/art/vegetation/"

# lpc_decorations rects (pixel-verified in town_builder.gd — shared idiom).
const R_LANTERN_LIT := Rect2(420, 64, 24, 32)
const R_BIG_TREE := Rect2(448, 292, 64, 122)
const R_SMALL_TREE := Rect2(416, 288, 32, 96)
const R_MONOLITH := Rect2(96, 0, 64, 96)
const R_STONE_TALL := Rect2(0, 0, 32, 62)
const R_STONE_LOW := Rect2(32, 14, 64, 48)
const R_MOUND := Rect2(160, 128, 32, 62)
const R_WELL := Rect2(0, 416, 64, 84)
const R_BONE_A := Rect2(64, 96, 32, 32)
const FIRE_FRAMES := [
	Rect2(256, 1504, 32, 64), Rect2(288, 1504, 32, 64), Rect2(320, 1504, 32, 64),
	Rect2(352, 1504, 32, 64), Rect2(384, 1504, 32, 64),
]

## Biome ground palettes: which tiles paint the base, patch variants, and the
## world tint that sells the biome until dedicated packs land.
## grass atlas: rows 0-3 pure grass; stone atlas: rows 0-2 slabs.
const _PALETTES := {
	"bog": {"tint": Color(1.0, 1.0, 1.0), "patch_chance": 0.0, "tree_tint": Color(0.72, 0.74, 0.66),
		"ground_sheet": "res://assets/art/world/dead_swamp/mud_96x128.png", "ground_cols": 3, "ground_rows": 4,
		"tree_set": ["res://assets/art/vegetation/plant_00.png", "res://assets/art/vegetation/plant_01.png", "res://assets/art/world/deadforest/birch_dead.png", "res://assets/art/world/deadforest/tree_dark1.png", "res://assets/art/vegetation/plant_02.png"]},
	"moor": {"tint": Color(0.86, 0.84, 0.74), "patch_chance": 0.10, "tree_tint": Color(0.72, 0.72, 0.60)},
	"wilds": {"tint": Color(0.92, 0.92, 0.84), "patch_chance": 0.08, "tree_tint": Color(0.80, 0.82, 0.68)},
	"farmland": {"tint": Color(1.0, 0.98, 0.88), "patch_chance": 0.06, "tree_tint": Color(0.86, 0.88, 0.72)},
	"deadforest": {"tint": Color(0.82, 0.82, 0.80), "patch_chance": 0.14, "tree_tint": Color(0.95, 0.95, 0.95),
		"tree_set": ["res://assets/art/world/deadforest/birch_dead.png", "res://assets/art/world/deadforest/tree_dark1.png", "res://assets/art/world/deadforest/tree_dark2.png"]},
	"tundra": {"tint": Color(0.96, 0.97, 1.0), "patch_chance": 0.0, "tree_tint": Color(0.78, 0.80, 0.90), "cold": true,
		"ground_sheet": "res://assets/art/world/snow/snow_96x64.png", "ground_cols": 3, "ground_rows": 2,
		"tree_set": ["res://assets/art/world/deadforest/birch_dead.png", "res://assets/art/world/deadforest/tree_dark1.png", "res://assets/art/world/deadforest/tree_dark2.png"]},
	"volcanic": {"tint": Color(0.86, 0.80, 0.78), "patch_chance": 0.0, "tree_tint": Color(0.72, 0.66, 0.64),
		"ground_sheet": "res://assets/art/world/volcanic/basalt_128x64.png", "ground_cols": 4, "ground_rows": 2,
		"rocky": true, "rock_set": ["res://assets/art/world/volcanic/rock_a.png", "res://assets/art/world/volcanic/rock_b.png",
			"res://assets/art/world/volcanic/rock_c.png", "res://assets/art/world/volcanic/rock_d.png",
			"res://assets/art/world/volcanic/cairn.png"],
		"tree_set": ["res://assets/art/world/volcanic/tree_burnt1.png", "res://assets/art/world/volcanic/tree_burnt2.png",
			"res://assets/art/world/volcanic/scrub1.png", "res://assets/art/world/volcanic/scrub2.png"]},
	"ridge": {"tint": Color(0.80, 0.82, 0.80), "patch_chance": 0.12, "tree_tint": Color(0.64, 0.68, 0.62), "rocky": true},
	"steppe": {"tint": Color(1.0, 0.94, 0.70), "patch_chance": 0.10, "tree_tint": Color(0.88, 0.82, 0.56)},
	"blestem": {"tint": Color(0.60, 0.58, 0.68), "patch_chance": 0.0, "tree_tint": Color(0.45, 0.44, 0.54),
		"ground_sheet": "res://assets/art/world/volcanic/basalt_128x64.png", "ground_cols": 4, "ground_rows": 2},
	"port": {"tint": Color(0.76, 0.80, 0.82), "patch_chance": 0.10, "tree_tint": Color(0.58, 0.62, 0.62)},
	"cave": {"tint": Color(0.52, 0.50, 0.56), "patch_chance": 0.0, "tree_tint": Color(0.5, 0.5, 0.55),
		"ground_sheet": "res://assets/art/world/dead_swamp/mud_96x128.png", "ground_cols": 3, "ground_rows": 4,
		"wall_rocks": true, "no_trees": true},
}


static func build_zone(parent: Node2D, def: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(def.get("id", "zone")))
	var tiles_w: int = int(def.get("tiles_w", 256))
	var tiles_h: int = int(def.get("tiles_h", 192))
	var biome: String = str(def.get("biome", "wilds"))
	var pal_key: String = str(def.get("palette", biome))
	var pal: Dictionary = _PALETTES.get(pal_key, _PALETTES["wilds"])

	var keep_clear: Array[Rect2] = []
	for lm_v: Variant in def.get("landmarks", []):
		var lm: Dictionary = lm_v
		var p: Vector2 = lm["pos"]
		keep_clear.append(Rect2(p - Vector2(140, 120), Vector2(280, 240)))
	for vg_v: Variant in def.get("vignettes", []):
		var vg: Dictionary = vg_v
		keep_clear.append(Rect2((vg["pos"] as Vector2) - Vector2(90, 70), Vector2(180, 140)))

	_build_ground(parent, rng, tiles_w, tiles_h, pal, def)
	_build_sea(parent, tiles_w, tiles_h, def, keep_clear)
	_build_river(parent, def)
	for rp_v: Variant in def.get("river", []):
		keep_clear.append(Rect2((rp_v as Vector2) - Vector2(180, 130), Vector2(360, 260)))
	var road_rects: Array[Rect2] = _build_roads(parent, def, pal.has("ground_sheet"))
	for rr: Rect2 in road_rects:
		# inflate: a tree planted at the rect edge still leans its trunk
		# and canopy over the slabs
		keep_clear.append(rr.grow(44.0))
	var decal_rects: Array[Rect2] = _ground_breakup(parent, rng, tiles_w, tiles_h, pal, keep_clear)
	keep_clear.append_array(decal_rects)
	_build_warm_ground(parent, rng, def)
	_scatter_vegetation(parent, rng, tiles_w, tiles_h, pal, def, keep_clear)
	_build_landmarks(parent, rng, def)
	_build_vignettes(parent, def)
	_build_waystation(parent, def)
	_build_border_wall(parent, rng, tiles_w, tiles_h, pal, def)

	_validate_forty_second_rule(def, tiles_w, tiles_h)

	var bounds := Rect2(0, 0, tiles_w * TILE, tiles_h * TILE)
	return {
		"player_spawn": def.get("player_spawn", Vector2(tiles_w * TILE * 0.5, tiles_h * TILE * 0.5)),
		"npc_spawns": def.get("npc_spawns", {}),
		"bounds": bounds,
		"enemy_spawns": _enemy_spawns(rng, def),
		"ambient_spawns": def.get("ambient_spawns", []),
	}


# --- ground -----------------------------------------------------------------


static func _build_ground(parent: Node2D, rng: RandomNumberGenerator, w: int, h: int,
		pal: Dictionary, def: Dictionary) -> void:
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var sheet_path: String = str(pal.get("ground_sheet", GRASS_SHEET))
	var cols: int = int(pal.get("ground_cols", 8))
	var rows: int = int(pal.get("ground_rows", 4))
	var src := TileSetAtlasSource.new()
	src.texture = load(sheet_path)
	src.texture_region_size = Vector2i(TILE, TILE)
	for y in range(rows):
		for x in range(cols):
			src.create_tile(Vector2i(x, y))
	ts.add_source(src, 0)

	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = ts
	layer.z_index = -10
	layer.modulate = pal["tint"]
	var patch: float = float(pal["patch_chance"])
	var packed: bool = pal.has("ground_sheet")
	for ty in range(h):
		for tx in range(w):
			var cell := Vector2i(0, 0)
			if packed:
				# Pack ground sheets tile as a repeating block — keep the sheet's
				# own pattern seamless instead of randomizing cells.
				cell = Vector2i(tx % cols, ty % rows)
			elif rng.randf() < patch:
				cell = Vector2i(rng.randi_range(0, 3), rng.randi_range(1, 3))
			elif rng.randf() < 0.25:
				cell = Vector2i(rng.randi_range(1, 3), 0)
			layer.set_cell(Vector2i(tx, ty), 0, cell)
	parent.add_child(layer)


## Slow shader-scrolled river along an authored polyline (the Iron Vein reads
## copper-dark; canals grey-black). Water color comes from the def.
static func _build_river(parent: Node2D, def: Dictionary) -> void:
	var pts: Array = def.get("river", [])
	if pts.size() < 2:
		return
	var line := Line2D.new()
	line.name = "River"
	line.z_index = -8
	for p: Variant in pts:
		line.add_point(p as Vector2)
	line.width = float(def.get("river_width", 96.0))
	line.default_color = def.get("river_color", Color(0.30, 0.24, 0.20, 0.92))
	line.joint_mode = Line2D.LINE_JOINT_ROUND
	line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	line.end_cap_mode = Line2D.LINE_CAP_ROUND
	# BANKS first (under the water): a wider dark mud edge so the river reads
	# as a cut channel, not a painted smear (sitting-#1 finding).
	var bank := Line2D.new()
	bank.z_index = -9
	for p: Variant in pts:
		bank.add_point(p as Vector2)
	bank.width = line.width * 1.35
	bank.default_color = Color(0.20, 0.16, 0.13, 0.85)
	bank.joint_mode = Line2D.LINE_JOINT_ROUND
	bank.begin_cap_mode = Line2D.LINE_CAP_ROUND
	bank.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(bank)
	parent.add_child(line)
	# water sheen: cool highlight + a second ripple strip, both animated slow
	var sheen := Line2D.new()
	sheen.z_index = -7
	for p: Variant in pts:
		sheen.add_point(p as Vector2)
	sheen.width = line.width * 0.45
	sheen.default_color = Color(0.55, 0.62, 0.68, 0.10)
	parent.add_child(sheen)
	var ripple := Line2D.new()
	ripple.z_index = -7
	for p: Variant in pts:
		ripple.add_point((p as Vector2) + Vector2(0, 8))
	ripple.width = line.width * 0.16
	ripple.default_color = Color(0.72, 0.76, 0.80, 0.08)
	parent.add_child(ripple)
	var tw := parent.create_tween().set_loops()
	tw.tween_property(sheen, "default_color:a", 0.16, 2.2)
	tw.tween_property(sheen, "default_color:a", 0.07, 2.6)


static func _build_roads(parent: Node2D, def: Dictionary, packed_ground: bool = false) -> Array[Rect2]:
	var rects: Array[Rect2] = []
	var roads: Array = def.get("roads", [])
	if roads.is_empty():
		return rects
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE, TILE)
	var grass := TileSetAtlasSource.new()
	grass.texture = load(GRASS_SHEET)
	grass.texture_region_size = Vector2i(TILE, TILE)
	for y in range(4, 8):
		for x in range(8):
			grass.create_tile(Vector2i(x, y))
	ts.add_source(grass, 0)
	# Solid stone slabs for roads over pack ground (grass-slab tiles let the
	# ground bleed through — sitting-#1 "translucent debug path" finding).
	var stone := TileSetAtlasSource.new()
	stone.texture = load(STONE_SHEET)
	stone.texture_region_size = Vector2i(TILE, TILE)
	for y in range(3):
		for x in range(3):
			stone.create_tile(Vector2i(x, y))
	ts.add_source(stone, 1)
	var layer := TileMapLayer.new()
	layer.name = "Roads"
	layer.tile_set = ts
	layer.z_index = -9
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(def.get("id")) + "roads")
	for road_v: Variant in roads:
		var road: Array = road_v
		for i in range(road.size() - 1):
			var a: Vector2 = road[i]
			var b: Vector2 = road[i + 1]
			var steps: int = int(a.distance_to(b) / (TILE * 0.5)) + 1
			for s in range(steps + 1):
				var p: Vector2 = a.lerp(b, float(s) / float(steps))
				var c := Vector2i(int(p.x / TILE), int(p.y / TILE))
				# Solid contiguous 2-wide slab road on EVERY biome — the grass-slab
				# variants read as scattered squares (sitting-#1 round 2).
				layer.set_cell(c, 1, Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2)))
				layer.set_cell(c + Vector2i(0, 1), 1, Vector2i(rng.randi_range(0, 2), rng.randi_range(0, 2)))
				rects.append(Rect2(p - Vector2(44, 44), Vector2(88, 88)))
	parent.add_child(layer)
	return rects


## Canon: warm ground = Underlanguage executing. Subtle warm decal circles with
## a faint heat light; dust-alignment sold with thin parallel scratches.
static func _build_warm_ground(parent: Node2D, rng: RandomNumberGenerator, def: Dictionary) -> void:
	for wp_v: Variant in def.get("warm_patches", []):
		var pos: Vector2 = wp_v
		var glow := PointLight2D.new()
		glow.position = pos
		glow.texture = _radial_tex()
		glow.color = Color(1.0, 0.62, 0.35)
		glow.energy = 0.35
		glow.texture_scale = 2.2
		parent.add_child(glow)
		var wstain := Sprite2D.new()
		wstain.texture = _radial_tex()
		wstain.position = pos
		wstain.scale = Vector2(0.7, 0.4)
		wstain.modulate = Color(0.55, 0.38, 0.22, 0.26)
		wstain.z_index = -7
		parent.add_child(wstain)
		for i in range(3):
			var scratch := ColorRect.new()
			scratch.color = Color(0.55, 0.44, 0.32, 0.35)
			scratch.size = Vector2(rng.randf_range(14, 24), 1)
			scratch.position = pos + Vector2(rng.randf_range(-16, 6), -10 + i * 8)
			scratch.z_index = -6
			parent.add_child(scratch)


static var _radial: Texture2D = null
static func _radial_tex() -> Texture2D:
	if _radial != null:
		return _radial
	var g := Gradient.new()
	g.set_color(0, Color(1, 1, 1, 1))
	g.set_color(1, Color(1, 1, 1, 0))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.width = 128
	t.height = 128
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(0.5, 0.0)
	_radial = t
	return t


# --- vegetation ---------------------------------------------------------------


static func _scatter_vegetation(parent: Node2D, rng: RandomNumberGenerator, w: int, h: int,
		pal: Dictionary, def: Dictionary, keep_clear: Array[Rect2]) -> void:
	var world_w: float = w * TILE
	var world_h: float = h * TILE
	var tree_tint: Color = pal["tree_tint"]
	var density: float = float(def.get("tree_density", 1.0))
	var n_trees: int = int(world_w * world_h / 90000.0 * density)
	if bool(pal.get("no_trees", false)):
		n_trees = 0
	var rocky: bool = bool(pal.get("rocky", false))
	var tree_set: Array = pal.get("tree_set", [])
	for i in range(n_trees):
		var pos := Vector2(rng.randf_range(60, world_w - 60), rng.randf_range(60, world_h - 60))
		if _in_any(pos, keep_clear):
			continue
		var spr := Sprite2D.new()
		if rocky and rng.randf() < 0.4:
			# Ridge country: boulders share the treeline (no sway on stone).
			var rocks: Array = pal.get("rock_set", [])
			if rocks.is_empty():
				spr.texture = load(PROPS + "cainos_prop_%02d.png" % rng.randi_range(33, 42))
			else:
				spr.texture = load(str(rocks[rng.randi_range(0, rocks.size() - 1)]))
			spr.scale = Vector2.ONE * rng.randf_range(0.9, 1.6)
			spr.position = pos
			spr.y_sort_enabled = true
			parent.add_child(spr)
			continue
		if not tree_set.is_empty():
			spr.texture = load(str(tree_set[rng.randi_range(0, tree_set.size() - 1)]))
		else:
			spr.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(0, 2))
		spr.material = _tree_sway_material()
		spr.position = pos
		spr.offset = Vector2(0, -spr.texture.get_height() * 0.5 + 10)
		spr.modulate = tree_tint
		spr.y_sort_enabled = true
		parent.add_child(spr)
	var n_bush: int = n_trees * 2
	for i in range(n_bush):
		var pos := Vector2(rng.randf_range(40, world_w - 40), rng.randf_range(40, world_h - 40))
		if _in_any(pos, keep_clear):
			continue
		var spr := Sprite2D.new()
		spr.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(3, 14))
		spr.position = pos
		spr.modulate = tree_tint.lightened(0.1)
		parent.add_child(spr)


static func _in_any(p: Vector2, rects: Array[Rect2]) -> bool:
	for r in rects:
		if r.has_point(p):
			return true
	return false


# --- landmarks & vignettes ----------------------------------------------------


## Landmark types compose existing kit art; each type is a hand-placeable
## set-piece. New types land here as packs arrive (forge, dock, spire...).
static func _build_landmarks(parent: Node2D, rng: RandomNumberGenerator, def: Dictionary) -> void:
	for lm_v: Variant in def.get("landmarks", []):
		var lm: Dictionary = lm_v
		var pos: Vector2 = lm["pos"]
		match str(lm.get("type", "")):
			"cottage":
				_sprite(parent, "res://assets/art/buildings/house_01.png", pos, true,
						lm.get("tint", Color.WHITE))
			"tavern":
				_sprite(parent, "res://assets/art/buildings/house_04.png", pos, true)
				_atlas(parent, R_LANTERN_LIT, pos + Vector2(-60, 40), Color(1, 0.9, 0.6))
				_fire_light(parent, pos + Vector2(-60, 36))
			"barn":
				_sprite(parent, "res://assets/art/buildings/house_03.png", pos, true)
			"shed":
				_sprite(parent, "res://assets/art/buildings/house_07.png", pos, true)
			"well":
				_sprite(parent, PROPS + "szadi_prop_11.png", pos, true)
			"copper_well":
				_sprite(parent, PROPS + "szadi_prop_11.png", pos, true, Color(0.95, 0.72, 0.52))
				_warm_light(parent, pos, 0.3)
			"inscription_stone":
				_atlas(parent, R_MONOLITH, pos, Color(0.82, 0.84, 0.88), true)
				var live: bool = bool(lm.get("live", false))
				_stone_light(parent, pos, live)
			"stone_row":
				for i in range(int(lm.get("count", 4))):
					_atlas(parent, R_STONE_TALL, pos + Vector2(i * 44, rng.randf_range(-6, 6)), Color(0.86, 0.88, 0.9), true)
			"camp":
				# char circle + stone ring ground the fire; bedrolls fan
				# around it (a straight pale row read as grave plots).
				var char_st := Sprite2D.new()
				char_st.texture = _radial_tex()
				char_st.position = pos
				char_st.scale = Vector2(0.42, 0.30)
				char_st.modulate = Color(0.12, 0.10, 0.09, 0.75)
				char_st.z_index = -6
				parent.add_child(char_st)
				for ri in range(6):
					var ra: float = TAU * float(ri) / 6.0 + 0.3
					var ring := Sprite2D.new()
					ring.texture = load(PROPS + "cainos_prop_%02d.png" % (33 + ri % 4))
					ring.position = pos + Vector2(cos(ra) * 26.0, sin(ra) * 18.0)
					ring.scale = Vector2.ONE * 0.35
					ring.z_index = -5
					parent.add_child(ring)
				_fire(parent, pos)
				for i in range(3):
					var ba: float = -PI * 0.15 + PI * 0.55 * float(i)
					var bed := Sprite2D.new()
					var bat := AtlasTexture.new()
					bat.atlas = load(DECOR)
					bat.region = R_MOUND
					bed.texture = bat
					bed.position = pos + Vector2(cos(ba) * 78.0, sin(ba) * 56.0 + 20.0)
					bed.rotation = ba * 0.35
					bed.modulate = Color(0.82, 0.62, 0.45)
					bed.y_sort_enabled = true
					parent.add_child(bed)
			"graves":
				for i in range(int(lm.get("count", 6))):
					var gp: Vector2 = pos + Vector2((i % 3) * 48, int(float(i) / 3.0) * 58)
					_atlas(parent, R_STONE_LOW if i % 2 == 0 else R_STONE_TALL, gp, Color(0.85, 0.87, 0.9), true)
			"dolmen":
				_atlas(parent, R_MONOLITH, pos, Color(0.8, 0.82, 0.86), true)
				_atlas(parent, R_STONE_LOW, pos + Vector2(-52, 30), Color(0.8, 0.82, 0.86), true)
				_atlas(parent, R_STONE_LOW, pos + Vector2(52, 30), Color(0.8, 0.82, 0.86), true)
			"bones":
				for i in range(4):
					_atlas(parent, R_BONE_A, pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30)), Color(0.95, 0.95, 0.9))
			"ore_rocks":
				# Rust-tinted rock cluster + glint — the zone fantasy made visible.
				for oi in range(int(lm.get("count", 5))):
					var op: Vector2 = pos + Vector2(rng.randf_range(-70, 70), rng.randf_range(-50, 50))
					_sprite(parent, PROPS + "cainos_prop_%02d.png" % rng.randi_range(33, 42), op, true,
							Color(0.85, 0.62, 0.48))
				_warm_light(parent, pos, 0.22)
			"rocks":
				for oi in range(int(lm.get("count", 4))):
					var op: Vector2 = pos + Vector2(rng.randf_range(-60, 60), rng.randf_range(-45, 45))
					_sprite(parent, PROPS + "cainos_prop_%02d.png" % rng.randi_range(33, 42), op, true)
			"pier":
				# grey-wood pier: plank deck marching into the water
				var pdir: Vector2 = Vector2(-1, 0) if str(lm.get("dir", "w")) == "w" else Vector2(0, 1)
				for pi in range(int(lm.get("count", 6))):
					var deck := ColorRect.new()
					deck.size = Vector2(34, 62) if pdir.x != 0 else Vector2(62, 34)
					deck.position = pos + pdir * float(pi) * (32.0 if pdir.x != 0 else 32.0) - deck.size * 0.5
					deck.color = Color(0.42, 0.33, 0.24) if pi % 2 == 0 else Color(0.38, 0.30, 0.22)
					deck.z_index = -6
					parent.add_child(deck)
					if pi % 2 == 1:
						for side in [-1.0, 1.0]:
							var post := ColorRect.new()
							post.size = Vector2(5, 10)
							post.position = pos + pdir * float(pi) * 32.0 + (Vector2(0, side * 28.0) if pdir.x != 0 else Vector2(side * 28.0, 0)) - Vector2(2.5, 5)
							post.color = Color(0.24, 0.19, 0.14)
							post.z_index = -5
							parent.add_child(post)
			"boat":
				var bspr := Sprite2D.new()
				bspr.texture = load("res://assets/art/world/coast/%s.png" % ("rowboat" if str(lm.get("kind", "")) == "row" else "sailboat"))
				bspr.position = pos
				bspr.y_sort_enabled = true
				parent.add_child(bspr)
				var btw := parent.create_tween().set_loops()
				btw.tween_property(bspr, "position:y", pos.y - 2.0, 1.6)
				btw.tween_property(bspr, "position:y", pos.y + 2.0, 1.6)
			"wreck":
				var wspr := Sprite2D.new()
				wspr.texture = load("res://assets/art/world/coast/sailboat.png")
				wspr.position = pos
				wspr.rotation = 0.5
				wspr.modulate = Color(0.45, 0.44, 0.50)
				wspr.y_sort_enabled = true
				parent.add_child(wspr)
				var wl := ColorRect.new()
				wl.size = Vector2(80, 22)
				wl.position = pos + Vector2(-40, 12)
				wl.color = Color(0.15, 0.19, 0.25, 0.85)
				wl.z_index = 1
				parent.add_child(wl)
			"warehouse":
				_sprite(parent, "res://assets/art/buildings/house_03.png", pos, true, Color(0.60, 0.62, 0.66))
			"crane":
				var mast := ColorRect.new()
				mast.size = Vector2(7, 74)
				mast.position = pos + Vector2(-3.5, -74)
				mast.color = Color(0.32, 0.25, 0.17)
				parent.add_child(mast)
				var arm := ColorRect.new()
				arm.size = Vector2(56, 6)
				arm.position = pos + Vector2(0, -70)
				arm.color = Color(0.36, 0.28, 0.19)
				parent.add_child(arm)
				var rope := Line2D.new()
				rope.add_point(pos + Vector2(52, -64))
				rope.add_point(pos + Vector2(52, -22))
				rope.width = 1.5
				rope.default_color = Color(0.72, 0.66, 0.52)
				parent.add_child(rope)
				var hook_crate := ColorRect.new()
				hook_crate.size = Vector2(18, 16)
				hook_crate.position = pos + Vector2(43, -22)
				hook_crate.color = Color(0.48, 0.36, 0.22)
				parent.add_child(hook_crate)
			"cargo":
				for ci in range(int(lm.get("count", 3))):
					var crate := ColorRect.new()
					crate.size = Vector2(20, 18)
					crate.position = pos + Vector2(float(ci % 2) * 24.0 - 12.0, float(int(float(ci) / 2.0)) * 20.0 - 10.0)
					crate.color = Color(0.50, 0.38, 0.24) if ci % 2 == 0 else Color(0.44, 0.33, 0.21)
					parent.add_child(crate)
					var slat := ColorRect.new()
					slat.size = Vector2(20, 2)
					slat.position = crate.position + Vector2(0, 8)
					slat.color = Color(0.30, 0.22, 0.14)
					parent.add_child(slat)
			"salt_pan":
				var pan := Polygon2D.new()
				var pan_pts := PackedVector2Array()
				for pk in range(12):
					var pa: float = TAU * float(pk) / 12.0
					pan_pts.append(pos + Vector2(cos(pa) * 90.0, sin(pa) * 55.0))
				pan.polygon = pan_pts
				pan.color = Color(0.88, 0.87, 0.80)
				pan.z_index = -7
				parent.add_child(pan)
				for sk in range(4):
					var streak := ColorRect.new()
					streak.size = Vector2(rng.randf_range(20, 50), 2)
					streak.position = pos + Vector2(rng.randf_range(-60, 30), rng.randf_range(-30, 30))
					streak.color = Color(1, 1, 1, 0.55)
					streak.z_index = -6
					parent.add_child(streak)
			"drowned_fence":
				for fi in range(int(lm.get("count", 6))):
					var fpost := ColorRect.new()
					fpost.size = Vector2(5, 16 - float(fi % 3) * 3.0)
					fpost.position = pos + Vector2(float(fi) * 26.0, float(fi % 2) * 4.0)
					fpost.color = Color(0.30, 0.26, 0.22)
					parent.add_child(fpost)
			"ledger_tablet":
				# the debt-grammar made object: a filed stone tablet
				var tab := ColorRect.new()
				tab.size = Vector2(22, 28)
				tab.position = pos - Vector2(11, 14)
				tab.color = Color(0.52, 0.54, 0.58)
				parent.add_child(tab)
				var tab_rim := ColorRect.new()
				tab_rim.size = Vector2(22, 3)
				tab_rim.position = pos - Vector2(11, 14)
				tab_rim.color = Color(0.40, 0.42, 0.47)
				parent.add_child(tab_rim)
				for li2 in range(3):
					var rune := ColorRect.new()
					rune.size = Vector2(14, 2)
					rune.position = pos + Vector2(-7, -6 + float(li2) * 6.0)
					rune.color = Color(0.34, 0.36, 0.40)
					parent.add_child(rune)
				if bool(lm.get("live", false)):
					var tl2 := PointLight2D.new()
					tl2.position = pos
					tl2.texture = _radial_tex()
					tl2.color = Color(1.0, 0.55, 0.2)
					tl2.energy = 0.3
					tl2.texture_scale = 1.0
					parent.add_child(tl2)
			"lone_tree":
				# one living tree in a dead land — it is noticed
				var lt := Sprite2D.new()
				lt.texture = load(PLANTS + "plant_00.png")
				lt.position = pos
				lt.offset = Vector2(0, -lt.texture.get_height() * 0.5 + 10)
				lt.y_sort_enabled = true
				lt.material = _tree_sway_material()
				parent.add_child(lt)
			"chimney_smoke":
				# def pos = the HOUSE anchor; the emitter climbs to the
				# chimney mouth (house_01 family: ~+68,-285 from the base)
				var smoke := CPUParticles2D.new()
				smoke.position = pos + Vector2(68, -285)
				smoke.amount = 7
				smoke.lifetime = 3.2
				smoke.preprocess = 3.0
				smoke.direction = Vector2(0.15, -1.0)
				smoke.spread = 9.0
				smoke.gravity = Vector2(4.0, -14.0)
				smoke.initial_velocity_min = 10.0
				smoke.initial_velocity_max = 18.0
				smoke.scale_amount_min = 5.0
				smoke.scale_amount_max = 9.0
				smoke.amount = 12
				smoke.color = Color(0.80, 0.78, 0.76, 0.55)
				smoke.color_ramp = _smoke_ramp()
				smoke.z_index = 4
				parent.add_child(smoke)
			"cairn":
				_sprite(parent, "res://assets/art/world/volcanic/cairn.png", pos, true)
			"signboard":
				_sprite(parent, "res://assets/art/world/volcanic/signboard.png", pos, true)
			"lava_vent":
				# Active vent: erupting basalt mound, ember light breathing.
				var vt := ["vent_big1", "vent_big2", "vent_ring1", "vent_ring2", "vent_small"]
				_sprite(parent, "res://assets/art/world/volcanic/%s.png" % vt[rng.randi_range(0, vt.size() - 1)], pos, true)
				var vl := PointLight2D.new()
				vl.position = pos + Vector2(0, -6)
				vl.texture = _radial_tex()
				vl.color = Color(1.0, 0.45, 0.15)
				vl.energy = 0.7
				vl.texture_scale = 1.6
				parent.add_child(vl)
				var vtw := parent.create_tween().set_loops()
				vtw.tween_property(vl, "energy", 0.4, rng.randf_range(0.9, 1.5))
				vtw.tween_property(vl, "energy", 0.85, rng.randf_range(0.7, 1.2))
			"brazier":
				_fire(parent, pos, true)
			"forge":
				# Sangeroasa forge-hall: soot-dark workshop, furnace maw burning.
				_sprite(parent, "res://assets/art/buildings/house_00.png", pos, true, Color(0.55, 0.48, 0.46))
				var fl := PointLight2D.new()
				fl.position = pos + Vector2(0, 34)
				fl.texture = _radial_tex()
				fl.color = Color(1.0, 0.5, 0.18)
				fl.energy = 0.85
				fl.texture_scale = 2.0
				parent.add_child(fl)
				var ftw := parent.create_tween().set_loops()
				ftw.tween_property(fl, "energy", 0.55, 0.5)
				ftw.tween_property(fl, "energy", 0.95, 0.4)
				_fire(parent, pos + Vector2(52, 40), true)
			"pit":
				# The Debt Pit: a black mouth in the basalt, ringed in stone,
				# ember-lit from far below (lore 04/08: the raw debt-node).
				var pit := Polygon2D.new()
				var ppts := PackedVector2Array()
				for pi in range(24):
					var pa: float = TAU * float(pi) / 24.0
					ppts.append(pos + Vector2(cos(pa) * 150.0, sin(pa) * 95.0))
				pit.polygon = ppts
				pit.color = Color(0.05, 0.03, 0.05)
				pit.z_index = -5
				parent.add_child(pit)
				var inner := Polygon2D.new()
				var ipts := PackedVector2Array()
				for pi in range(24):
					var pa2: float = TAU * float(pi) / 24.0
					ipts.append(pos + Vector2(cos(pa2) * 96.0, sin(pa2) * 60.0))
				inner.polygon = ipts
				inner.color = Color(0.0, 0.0, 0.0)
				inner.z_index = -4
				parent.add_child(inner)
				for pi in range(12):
					var pa3: float = TAU * float(pi) / 12.0 + rng.randf_range(-0.1, 0.1)
					_sprite(parent, "res://assets/art/world/volcanic/rock_%s.png" % ["a", "b", "c", "d"][rng.randi_range(0, 3)],
							pos + Vector2(cos(pa3) * 165.0, sin(pa3) * 108.0), true)
				var el := PointLight2D.new()
				el.position = pos
				el.texture = _radial_tex()
				el.color = Color(0.9, 0.3, 0.1)
				el.energy = 0.35
				el.texture_scale = 2.2
				parent.add_child(el)
				var etw := parent.create_tween().set_loops()
				etw.tween_property(el, "energy", 0.18, 2.3)
				etw.tween_property(el, "energy", 0.4, 1.9)
			"gift_field":
				# The Gift: bands of impossibly red soil grown from the war
				# dead — and things growing out of it (lore 03/08).
				var mud := load("res://assets/art/world/dead_swamp/mud_96x128.png")
				var gw: int = int(lm.get("w", 6))
				var gh: int = int(lm.get("h", 3))
				for gy in range(gh):
					for gx in range(gw):
						# ragged band: corners and edges thin out organically
						var edge: bool = gx == 0 or gy == 0 or gx == gw - 1 or gy == gh - 1
						if edge and rng.randf() < 0.35:
							continue
						var at := AtlasTexture.new()
						at.atlas = mud
						at.region = Rect2(float(rng.randi_range(0, 2)) * 32.0, float(rng.randi_range(0, 3)) * 32.0, 32.0, 32.0)
						var soil := Sprite2D.new()
						soil.texture = at
						soil.position = pos + Vector2(float(gx) * 32.0, float(gy) * 32.0)
						var glow: float = rng.randf_range(0.82, 1.05)
						soil.modulate = Color(0.92 * glow, 0.38 * glow, 0.32 * glow)
						soil.z_index = -6
						parent.add_child(soil)
				for si in range(gw):
					# saplings, not oaks: the harvest is YOUNG (and wrong)
					var sprout := Sprite2D.new()
					sprout.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(0, 2))
					sprout.scale = Vector2.ONE * rng.randf_range(0.22, 0.34)
					sprout.position = pos + Vector2(rng.randf_range(16.0, float(gw) * 32.0 - 16.0), rng.randf_range(8.0, float(gh) * 32.0 - 8.0))
					sprout.modulate = Color(0.55, 0.95, 0.45)
					sprout.y_sort_enabled = true
					parent.add_child(sprout)
			"spire":
				# The Black Spire: windowless violet-black surveillance tower.
				# Under detection it bleeds shifting orange at its base (canon).
				_sprite(parent, "res://assets/art/buildings/house_02.png", pos + Vector2(0, 60), true, Color(0.22, 0.18, 0.30))
				_sprite(parent, "res://assets/art/buildings/house_02.png", pos, true, Color(0.18, 0.15, 0.26))
				_sprite(parent, "res://assets/art/buildings/house_02.png", pos + Vector2(0, -60), true, Color(0.14, 0.12, 0.22))
				var sp_l := PointLight2D.new()
				sp_l.position = pos + Vector2(0, 100)
				sp_l.texture = _radial_tex()
				sp_l.color = Color(1.0, 0.55, 0.15)
				sp_l.energy = 0.4
				sp_l.texture_scale = 2.4
				parent.add_child(sp_l)
				var sp_t := parent.create_tween().set_loops()
				sp_t.tween_property(sp_l, "energy", 0.18, 1.7)
				sp_t.tween_property(sp_l, "energy", 0.5, 1.3)
			"lamp":
				_atlas(parent, Rect2(354, 198, 24, 79), pos, Color(0.75, 0.72, 0.80), true)
				_atlas(parent, R_LANTERN_LIT, pos + Vector2(0, -58), Color(1, 0.9, 0.6))
				_fire_light(parent, pos + Vector2(0, -58), 0.55)
			"lichen_glow":
				# Bioluminescent lichen: the Strigoi export (canon) — teal glow.
				for li in range(int(lm.get("count", 4))):
					var lp: Vector2 = pos + Vector2(rng.randf_range(-90, 90), rng.randf_range(-60, 60))
					var patch := Sprite2D.new()
					patch.texture = load(PROPS + "szadi_prop_02.png")
					patch.position = lp
					patch.z_index = -6
					patch.rotation = rng.randf_range(0.0, TAU)
					patch.scale = Vector2.ONE * rng.randf_range(0.7, 1.4)
					patch.modulate = Color(rng.randf_range(0.30, 0.50), 0.95,
							rng.randf_range(0.75, 0.95), 0.9)
					parent.add_child(patch)
					var gl := PointLight2D.new()
					gl.position = lp
					gl.texture = _radial_tex()
					gl.color = Color(0.35, 0.95, 0.85)
					gl.energy = 0.75
					gl.texture_scale = 1.8
					parent.add_child(gl)
			"cabin":
				_sprite(parent, "res://assets/art/world/snow/log_cabin.png", pos, true)
			"dark_keep":
				# Blue-black keep: the manor silhouette in Black Night's stone.
				_sprite(parent, "res://assets/art/buildings/house_04.png", pos, true, Color(0.45, 0.48, 0.62))
				_sprite(parent, "res://assets/art/buildings/house_02.png", pos + Vector2(-170, 60), true, Color(0.42, 0.45, 0.58))
				_sprite(parent, "res://assets/art/buildings/house_02.png", pos + Vector2(170, 60), true, Color(0.42, 0.45, 0.58))
			"thread_lines":
				# The Thread: filaments of blue light threading the stone (canon).
				var tl_rng := RandomNumberGenerator.new()
				tl_rng.seed = hash(pos)
				for ti in range(int(lm.get("count", 5))):
					var a: Vector2 = pos + Vector2(tl_rng.randf_range(-260, 260), tl_rng.randf_range(-180, 180))
					var b: Vector2 = a + Vector2(tl_rng.randf_range(-160, 160), tl_rng.randf_range(-120, 120))
					var th := Line2D.new()
					th.add_point(a)
					th.add_point(a.lerp(b, 0.5) + Vector2(0, -14))
					th.add_point(b)
					th.width = 2.0
					th.default_color = Color(0.45, 0.65, 1.0, 0.55)
					th.z_index = 2
					parent.add_child(th)
					for anchor: Vector2 in [a, b]:
						var tp := Sprite2D.new()
						tp.texture = load(PROPS + "cainos_prop_17.png")
						tp.position = anchor + Vector2(0, 6)
						tp.scale = Vector2.ONE * 0.55
						tp.modulate = Color(0.55, 0.58, 0.72)
						tp.y_sort_enabled = true
						parent.add_child(tp)
					var tw := parent.create_tween().set_loops()
					tw.tween_property(th, "default_color:a", 0.25, 1.4 + float(ti) * 0.2)
					tw.tween_property(th, "default_color:a", 0.6, 1.2)
				_stone_light(parent, pos, false)
			"pond":
				_pond(parent, pos, rng)
				_bubbles(parent, pos + Vector2(rng.randf_range(-30, 30), rng.randf_range(-20, 20)), rng)
			"stump":
				_swamp_atlas(parent, Rect2(0, 256, 128, 128), pos, true)
			"trunk_hollow":
				_swamp_atlas(parent, Rect2(128, 128, 128, 160), pos, true)
			"manor":
				_sprite(parent, "res://assets/art/buildings/house_04.png", pos, true,
						lm.get("tint", Color.WHITE))
			"shop":
				_sprite(parent, "res://assets/art/buildings/house_02.png", pos, true)
			"workshop":
				_sprite(parent, "res://assets/art/buildings/house_00.png", pos, true)
			"hamlet":
				# Authored cottage cluster: N houses ringed around the anchor.
				var hn: int = int(lm.get("count", 4))
				for hi in range(hn):
					var ang: float = TAU * float(hi) / float(hn) + rng.randf_range(-0.2, 0.2)
					var dist: float = 190.0 + rng.randf_range(-20.0, 30.0)
					var hp: Vector2 = pos + Vector2(cos(ang), sin(ang) * 0.72) * dist
					var kinds: Array = ["house_01", "house_05", "house_06", "house_07"]
					_sprite(parent, "res://assets/art/buildings/%s.png" % kinds[hi % kinds.size()], hp, true)
			"stall":
				_atlas(parent, Rect2(0, 928, 96, 31), pos, Color.WHITE, true)
				for spx in [-40.0, 40.0]:
					var spole := ColorRect.new()
					spole.color = Color(0.32, 0.22, 0.13)
					spole.size = Vector2(4, 48)
					spole.position = pos + Vector2(spx - 2.0, -56.0)
					spole.z_index = 1
					parent.add_child(spole)
				_atlas(parent, Rect2(272, 800, 48, 64), pos + Vector2(0, -20), Color.WHITE, true)
			"plaza":
				for pi in range(int(lm.get("count", 4))):
					_sprite(parent, PROPS + "szadi_prop_01.png",
							pos + Vector2(float(pi % 2) * 150.0 - 75.0, float(int(float(pi) / 2.0)) * 120.0 - 60.0))
			"statue":
				_sprite(parent, PROPS + "cainos_prop_06.png", pos, true)
			"fountain":
				_sprite(parent, PROPS + "cainos_prop_30.png", pos, true)


## Lore vignettes: authored environmental-storytelling set-pieces (bible-sourced,
## 3 per region). v1 renders composition + an examine label; deeper interactions
## hook in via the quest system later.
static func _build_vignettes(parent: Node2D, def: Dictionary) -> void:
	for vg_v: Variant in def.get("vignettes", []):
		var vg: Dictionary = vg_v
		var pos: Vector2 = vg["pos"]
		match str(vg.get("kind", "")):
			"murder_scene":
				# A death the world stepped around. Stain, what is left,
				# drag-marks, and the thing they dropped. Examined text
				# hooks in via the quest system later.
				var mk_stain := Sprite2D.new()
				mk_stain.texture = _radial_tex()
				mk_stain.position = pos
				mk_stain.scale = Vector2(0.55, 0.34)
				mk_stain.modulate = Color(0.30, 0.10, 0.08, 0.55)
				mk_stain.z_index = -6
				parent.add_child(mk_stain)
				_atlas(parent, R_BONE_A, pos + Vector2(-6, -4), Color(0.90, 0.90, 0.86))
				_atlas(parent, R_BONE_A, pos + Vector2(14, 6), Color(0.86, 0.86, 0.82))
				for dm in range(3):
					var drag := ColorRect.new()
					drag.size = Vector2(26 - dm * 6, 2)
					drag.position = pos + Vector2(20 + dm * 14, 10 + dm * 5)
					drag.color = Color(0.32, 0.16, 0.12, 0.45)
					drag.z_index = -5
					parent.add_child(drag)
				var mk_drop := ColorRect.new()
				mk_drop.size = Vector2(9, 7)
				mk_drop.position = pos + Vector2(-22, 12)
				mk_drop.color = Color(0.55, 0.47, 0.28)
				parent.add_child(mk_drop)
			"courier_seal":
				# The Courier: intact, unmarked, dead of understanding. His
				# satchel still packed, wax seal unbroken (lore 614/1426).
				_atlas(parent, R_BONE_A, pos, Color(0.92, 0.92, 0.88))
				_atlas(parent, R_BONE_A, pos + Vector2(18, 8), Color(0.88, 0.88, 0.84))
				var sat := ColorRect.new()
				sat.size = Vector2(14, 10)
				sat.position = pos + Vector2(-24, -4)
				sat.color = Color(0.42, 0.30, 0.18)
				parent.add_child(sat)
				var strap := ColorRect.new()
				strap.size = Vector2(14, 2)
				strap.position = pos + Vector2(-24, -1)
				strap.color = Color(0.30, 0.20, 0.11)
				parent.add_child(strap)
				var wax := ColorRect.new()
				wax.size = Vector2(4, 4)
				wax.position = pos + Vector2(-19, -2)
				wax.color = Color(0.72, 0.12, 0.10)
				parent.add_child(wax)
			"burned_farmstead":
				# A peasant tried to copy Fielderine's discipline and failed:
				# charred farmhouse, a cheap lead box open and empty,
				# scratch-marks on the inside (lore 08 / Angel Wings).
				var bf_char := Sprite2D.new()
				bf_char.texture = _radial_tex()
				bf_char.position = pos
				bf_char.scale = Vector2(1.4, 0.9)
				bf_char.modulate = Color(0.10, 0.08, 0.08, 0.8)
				bf_char.z_index = -6
				parent.add_child(bf_char)
				_sprite(parent, "res://assets/art/buildings/house_05.png", pos, true, Color(0.16, 0.13, 0.12))
				var bf_box := ColorRect.new()
				bf_box.size = Vector2(10, 7)
				bf_box.position = pos + Vector2(44, 38)
				bf_box.color = Color(0.55, 0.58, 0.62)
				parent.add_child(bf_box)
				var bf_lid := ColorRect.new()
				bf_lid.size = Vector2(10, 3)
				bf_lid.position = pos + Vector2(56, 34)
				bf_lid.rotation = 0.5
				bf_lid.color = Color(0.48, 0.51, 0.55)
				parent.add_child(bf_lid)
			"childs_shoe":
				# A child's shoe pressed into the red soil, and a good harvest
				# growing out of the print (lore 08). Blink and you miss it.
				var sh_at := AtlasTexture.new()
				sh_at.atlas = load("res://assets/art/world/dead_swamp/mud_96x128.png")
				sh_at.region = Rect2(32, 32, 32, 32)
				var sh_patch := Sprite2D.new()
				sh_patch.texture = sh_at
				sh_patch.position = pos
				sh_patch.modulate = Color(0.92, 0.38, 0.32)
				sh_patch.z_index = -6
				parent.add_child(sh_patch)
				var sh_heel := ColorRect.new()
				sh_heel.size = Vector2(5, 4)
				sh_heel.position = pos + Vector2(-2, 2)
				sh_heel.color = Color(0.24, 0.14, 0.10)
				parent.add_child(sh_heel)
				var sh_toe := ColorRect.new()
				sh_toe.size = Vector2(6, 7)
				sh_toe.position = pos + Vector2(-3, -6)
				sh_toe.color = Color(0.28, 0.17, 0.12)
				parent.add_child(sh_toe)
				var sh_grow := Sprite2D.new()
				sh_grow.texture = load(PLANTS + "plant_00.png")
				sh_grow.scale = Vector2.ONE * 0.2
				sh_grow.position = pos + Vector2(1, -8)
				sh_grow.modulate = Color(0.5, 1.0, 0.42)
				parent.add_child(sh_grow)
			"standing_farmer":
				# A villager stood perfectly still, facing an authored direction.
				# Placed via npc-style sheet, no wander — stillness IS the horror.
				var spr := Sprite2D.new()
				var sheet: Texture2D = load("res://assets/art/characters/npc_male2.png")
				var at := AtlasTexture.new()
				at.atlas = sheet
				at.region = Rect2(0, (1 * 3 + 2) * 48, 32, 48)  # variant 1, up-facing idle
				spr.texture = at
				spr.position = pos
				spr.y_sort_enabled = true
				parent.add_child(spr)
				_dust_lines(parent, pos + Vector2(0, 30))
			"cold_camp":
				_fire(parent, pos, false)  # dead fire
				for i in range(3):
					_atlas(parent, R_MOUND, pos + Vector2(-46 + i * 46, 30), Color(0.75, 0.78, 0.85))
			"boot_prints":
				for i in range(12):
					var bp := ColorRect.new()
					bp.color = Color(0.30, 0.26, 0.22, 0.7)
					bp.size = Vector2(6, 10)
					bp.position = pos + Vector2((i % 6) * 14, int(float(i) / 6.0) * 18)
					bp.z_index = -6
					parent.add_child(bp)
			"empty_stall":
				_atlas(parent, Rect2(0, 928, 96, 31), pos, Color(0.92, 0.88, 0.8), true)
				_dust_lines(parent, pos + Vector2(10, 26))
			"rows_of_twelve":
				# Iele shells standing perfectly still, arranged in rows of
				# twelve — the Thread and the ledger speak the same tongue.
				for ri in range(12):
					var shell := Sprite2D.new()
					var sheet2: Texture2D = load("res://assets/art/characters/npc_male%d.png" % [1, 2, 3, 4][ri % 4])
					var at2 := AtlasTexture.new()
					at2.atlas = sheet2
					at2.region = Rect2(0, ((ri % 4) * 3 + 1) * 48, 32, 48)
					shell.texture = at2
					shell.position = pos + Vector2(float(ri % 6) * 40.0, float(int(float(ri) / 6.0)) * 52.0)
					shell.modulate = Color(0.62, 0.66, 0.82, 0.92)
					shell.y_sort_enabled = true
					parent.add_child(shell)
			"chalk_handprints":
				# Children's chalked handprints; ONE is faintly copper-stained
				# and warm to the touch. No one has noticed yet. (Canon hook.)
				for i in range(7):
					var hp := ColorRect.new()
					var warm: bool = i == 4
					hp.color = Color(0.92, 0.62, 0.42, 0.9) if warm else Color(0.88, 0.88, 0.92, 0.85)
					hp.size = Vector2(7, 9)
					hp.position = pos + Vector2(i * 12, (i % 2) * 6)
					hp.z_index = 3
					parent.add_child(hp)
				_warm_light(parent, pos + Vector2(52, 6), 0.18)
			"full_granary":
				_sprite(parent, "res://assets/art/buildings/house_03.png", pos, true)
				for i in range(4):
					_sprite(parent, PROPS + "szadi_prop_24.png", pos + Vector2(-40 + i * 26, 60), true)


static func _dust_lines(parent: Node2D, pos: Vector2) -> void:
	# Aligned-dust ground stain: layered soft ellipses + THIN short scores —
	# reads as disturbed earth (the old 3-bar version floated like a glyph).
	var stain := Sprite2D.new()
	stain.texture = _radial_tex()
	stain.position = pos
	stain.scale = Vector2(0.55, 0.28)
	stain.modulate = Color(0.42, 0.34, 0.24, 0.30)
	stain.z_index = -7
	parent.add_child(stain)
	for i in range(4):
		var ln := ColorRect.new()
		ln.color = Color(0.50, 0.42, 0.32, 0.38)
		ln.size = Vector2(16.0 + float(i % 2) * 6.0, 1)
		ln.position = pos + Vector2(-10.0 + float(i % 2) * 4.0, -6.0 + i * 5.0)
		ln.z_index = -6
		parent.add_child(ln)


static func _build_waystation(parent: Node2D, def: Dictionary) -> void:
	for ws_v: Variant in def.get("waystations", []):
		var ws: Dictionary = ws_v
		var pos: Vector2 = ws["pos"]
		_sprite(parent, PROPS + "cainos_prop_17.png", pos, true)  # signpost
		_atlas(parent, R_LANTERN_LIT, pos + Vector2(14, -12), Color(1, 0.9, 0.6))
		_fire_light(parent, pos + Vector2(14, -14), 0.5)
		TravelSystem.register_station(str(ws.get("id", "")), str(def.get("id", "")), pos)


## Open sea along named zone edges: dark band + animated sheen + keep-clear.
static func _build_sea(parent: Node2D, w: int, h: int, def: Dictionary,
		keep_clear: Array[Rect2]) -> void:
	var ww: float = w * TILE
	var wh: float = h * TILE
	const BAND := 300.0
	for e_v: Variant in def.get("sea_edges", []):
		var band := Rect2()
		match str(e_v):
			"west": band = Rect2(0, 0, BAND, wh)
			"east": band = Rect2(ww - BAND, 0, BAND, wh)
			"north": band = Rect2(0, 0, ww, BAND)
			"south": band = Rect2(0, wh - BAND, ww, BAND)
		var water := ColorRect.new()
		water.position = band.position
		water.size = band.size
		water.color = Color(0.15, 0.19, 0.25)
		water.z_index = -8
		parent.add_child(water)
		var horiz: bool = str(e_v) in ["north", "south"]
		for i in range(int((band.size.x if horiz else band.size.y) / 640.0) + 1):
			var sheen := Line2D.new()
			var sy: float = band.position.y + (60.0 + float(i * 640 % int(maxf(band.size.y - 90.0, 90.0))))
			var sx: float = band.position.x + (60.0 + float(i * 640 % int(maxf(band.size.x - 90.0, 90.0))))
			if horiz:
				sheen.add_point(Vector2(sx, band.position.y + band.size.y * 0.5))
				sheen.add_point(Vector2(sx + 90, band.position.y + band.size.y * 0.5 + 5))
			else:
				sheen.add_point(Vector2(band.position.x + band.size.x * 0.5, sy))
				sheen.add_point(Vector2(band.position.x + band.size.x * 0.5 + 70, sy + 4))
			sheen.width = 2.0
			sheen.default_color = Color(0.55, 0.66, 0.74, 0.35)
			sheen.z_index = -7
			parent.add_child(sheen)
			var stw := parent.create_tween().set_loops()
			stw.tween_property(sheen, "default_color:a", 0.12, 1.6 + float(i % 3) * 0.3)
			stw.tween_property(sheen, "default_color:a", 0.4, 1.4)
		keep_clear.append(band.grow(30.0))


## Ring of edge forest with authored gaps at travel seams (gap rects in def).
static func _build_border_wall(parent: Node2D, rng: RandomNumberGenerator, w: int, h: int,
		pal: Dictionary, def: Dictionary) -> void:
	var gaps: Array = def.get("border_gaps", [])
	for e_v: Variant in def.get("sea_edges", []):
		var ww2: float = w * TILE
		var wh2: float = h * TILE
		match str(e_v):
			"west": gaps.append(Rect2(0, 0, 340, wh2))
			"east": gaps.append(Rect2(ww2 - 340, 0, 340, wh2))
			"north": gaps.append(Rect2(0, 0, ww2, 340))
			"south": gaps.append(Rect2(0, wh2 - 340, ww2, 340))
	var world_w: float = w * TILE
	var world_h: float = h * TILE
	var step: float = 54.0
	var edges: Array = [
		[Vector2(30, 30), Vector2(world_w - 30, 30)],
		[Vector2(30, world_h - 24), Vector2(world_w - 30, world_h - 24)],
		[Vector2(30, 30), Vector2(30, world_h - 24)],
		[Vector2(world_w - 30, 30), Vector2(world_w - 30, world_h - 24)],
	]
	for e_v: Variant in edges:
		var e: Array = e_v
		var a: Vector2 = e[0]
		var b: Vector2 = e[1]
		var n: int = int(a.distance_to(b) / step)
		for i in range(n + 1):
			var pos: Vector2 = a.lerp(b, float(i) / float(n)) + Vector2(rng.randf_range(-10, 10), rng.randf_range(-8, 8))
			var skip := false
			for g_v: Variant in gaps:
				if (g_v as Rect2).has_point(pos):
					skip = true
					break
			if skip:
				continue
			var spr := Sprite2D.new()
			if bool(pal.get("wall_rocks", false)):
				spr.texture = load(PROPS + "cainos_prop_%02d.png" % rng.randi_range(33, 42))
				spr.scale = Vector2.ONE * rng.randf_range(1.4, 2.2)
				spr.modulate = Color(0.55, 0.53, 0.60)
			else:
				spr.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(0, 2))
				spr.offset = Vector2(0, -spr.texture.get_height() * 0.5 + 10)
				spr.modulate = (pal["tree_tint"] as Color).darkened(0.12)
				spr.material = _tree_sway_material()
			spr.y_sort_enabled = true
			parent.add_child(spr)
			var col := StaticBody2D.new()
			var cs := CollisionShape2D.new()
			var shape := CircleShape2D.new()
			shape.radius = 12.0
			cs.shape = shape
			col.position = pos
			cs.position = Vector2(0, -4)
			col.add_child(cs)
			parent.add_child(col)


# --- creatures ------------------------------------------------------------


## creature_table: [{type, name, count, hp, damage, speed, area:Rect2,
## patrol, pack:int}] — hand-authored per zone (native ecology). Spawns are
## clustered into packs inside the authored area.
static func _enemy_spawns(rng: RandomNumberGenerator, def: Dictionary) -> Array:
	var out: Array = []
	for row_v: Variant in def.get("creature_table", []):
		var row: Dictionary = row_v
		var area: Rect2 = row.get("area", Rect2(200, 200, 800, 600))
		var count: int = int(row.get("count", 3))
		var pack: int = maxi(1, int(row.get("pack", 1)))
		var i: int = 0
		while i < count:
			var anchor := Vector2(
				rng.randf_range(area.position.x, area.end.x),
				rng.randf_range(area.position.y, area.end.y))
			var etype: String = str(row.get("type", "skeleton"))
			for k in range(mini(pack, count - i)):
				# ring placement: pack members spread (sitting-#1: stacked blobs)
				var ang: float = TAU * float(k) / float(maxi(1, pack)) + rng.randf_range(-0.4, 0.4)
				var dist: float = 70.0 + rng.randf_range(0.0, 50.0)
				out.append({
					"type": etype,
					"display_name": str(row.get("name", "Creature")),
					"pos": anchor + Vector2(cos(ang), sin(ang) * 0.7) * dist,
					"hp": float(row.get("hp", 30.0)),
					"damage": float(row.get("damage", 6.0)),
					"speed": float(row.get("speed", 62.0)),
					"patrol_radius": float(row.get("patrol", 70.0)),
					# Wilderness fauna (wolf/boar/bear) use their own sheet flow.
					"fauna": etype in ["wolf", "boar", "bear"],
				})
			i += pack
	return out


# --- tiny shared helpers ----------------------------------------------------


static func _sprite(parent: Node2D, path: String, pos: Vector2, sorted: bool = false,
		tint: Color = Color.WHITE) -> void:
	if not ResourceLoader.exists(path):
		return
	var spr := Sprite2D.new()
	spr.texture = load(path)
	spr.position = pos
	spr.modulate = tint
	if sorted:
		spr.offset = Vector2(0, -spr.texture.get_height() * 0.5 + 8)
		spr.y_sort_enabled = true
	parent.add_child(spr)
	# Buildings occlude light: waystation lanterns / camp fires throw real
	# shadows off structures ("ray-traced" feel, 2D-style).
	if sorted and path.contains("/buildings/"):
		var occ := LightOccluder2D.new()
		var poly := OccluderPolygon2D.new()
		var w: float = spr.texture.get_width() * 0.32
		poly.polygon = PackedVector2Array([
			Vector2(-w, -10.0), Vector2(w, -10.0), Vector2(w, 6.0), Vector2(-w, 6.0),
		])
		occ.occluder = poly
		occ.position = pos
		parent.add_child(occ)


static func _atlas(parent: Node2D, rect: Rect2, pos: Vector2, tint: Color = Color.WHITE,
		sorted: bool = false) -> void:
	var at := AtlasTexture.new()
	at.atlas = load(DECOR)
	at.region = rect
	var spr := Sprite2D.new()
	spr.texture = at
	spr.position = pos
	spr.modulate = tint
	if sorted:
		spr.offset = Vector2(0, -rect.size.y * 0.5 + 6)
		spr.y_sort_enabled = true
	parent.add_child(spr)


static func _fire(parent: Node2D, pos: Vector2, lit: bool = true) -> void:
	if not lit:
		_atlas(parent, R_BONE_A, pos, Color(0.4, 0.38, 0.36))
		return
	var spr := AnimatedSprite2D.new()
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("burn")
	sf.set_animation_speed("burn", 8.0)
	sf.set_animation_loop("burn", true)
	for r: Variant in FIRE_FRAMES:
		var at := AtlasTexture.new()
		at.atlas = load(DECOR)
		at.region = r as Rect2
		sf.add_frame("burn", at)
	spr.sprite_frames = sf
	spr.position = pos
	spr.play("burn")
	parent.add_child(spr)
	_fire_light(parent, pos)


static func _fire_light(parent: Node2D, pos: Vector2, energy: float = 0.8) -> void:
	var l := PointLight2D.new()
	l.position = pos
	l.texture = _radial_tex()
	l.color = Color(1.0, 0.75, 0.45)
	l.energy = energy
	l.texture_scale = 3.0
	# AAA lighting: landmark fires cast REAL 2D shadows off occluders.
	l.shadow_enabled = true
	l.shadow_filter = PointLight2D.SHADOW_FILTER_PCF5
	l.shadow_filter_smooth = 2.4
	l.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	parent.add_child(l)


static func _warm_light(parent: Node2D, pos: Vector2, energy: float = 0.35) -> void:
	var l := PointLight2D.new()
	l.position = pos
	l.texture = _radial_tex()
	l.color = Color(1.0, 0.6, 0.35)
	l.energy = energy
	l.texture_scale = 1.6
	parent.add_child(l)


## Inscription stones: detection grammar — green = about to wake, shifting
## orange = live transmission point (canon colors).
static func _stone_light(parent: Node2D, pos: Vector2, live: bool) -> void:
	var l := PointLight2D.new()
	l.position = pos + Vector2(0, -20)
	l.texture = _radial_tex()
	l.color = Color(1.0, 0.55, 0.15) if live else Color(0.45, 0.9, 0.5)
	l.energy = 0.55 if live else 0.3
	l.texture_scale = 2.0
	parent.add_child(l)
	if live:
		var t := parent.create_tween().set_loops()
		t.tween_property(l, "energy", 0.25, 1.3)
		t.tween_property(l, "energy", 0.65, 1.1)


# --- Dead Swamp pack helpers (assets/art/world/dead_swamp, CC-BY Sevarihk) ---

const _SWAMP_TRUNKS := "res://assets/art/world/dead_swamp/trunks_256x1408.png"
const _SWAMP_POND := "res://assets/art/world/dead_swamp/pond_anim_384x128.png"


static func _swamp_atlas(parent: Node2D, rect: Rect2, pos: Vector2, sorted: bool = false) -> void:
	var at := AtlasTexture.new()
	at.atlas = load(_SWAMP_TRUNKS)
	at.region = rect
	var spr := Sprite2D.new()
	spr.texture = at
	spr.position = pos
	if sorted:
		spr.offset = Vector2(0, -rect.size.y * 0.5 + 10)
		spr.y_sort_enabled = true
	parent.add_child(spr)


## Animated murky pond: 3 frames of a 128x128 block on the pack sheet.
static func _pond(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("murk")
	sf.set_animation_speed("murk", 2.2)
	sf.set_animation_loop("murk", true)
	for i in range(3):
		var at := AtlasTexture.new()
		at.atlas = load(_SWAMP_POND)
		at.region = Rect2(i * 128, 0, 128, 128)
		sf.add_frame("murk", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.position = pos
	spr.z_index = -7
	spr.play("murk")
	spr.frame = rng.randi_range(0, 2)
	parent.add_child(spr)


# --- animation mandate: everything that can move, moves ---------------------

static var _sway_mat: ShaderMaterial = null


## One shared canvas_item shader sways every tree canopy on the GPU: phase is
## de-synced per tree by its world position, roots stay planted (sway scales
## with height above the pivot). Zero CPU cost, one material for the world.
static var _smoke_grad: Gradient = null


static func _smoke_ramp() -> Gradient:
	if _smoke_grad == null:
		_smoke_grad = Gradient.new()
		_smoke_grad.set_color(0, Color(0.85, 0.82, 0.80, 0.6))
		_smoke_grad.set_color(1, Color(0.85, 0.85, 0.85, 0.0))
	return _smoke_grad


static func _tree_sway_material() -> ShaderMaterial:
	if _sway_mat != null:
		return _sway_mat
	var sh := Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float strength = 1.6;
uniform float speed = 0.9;
void vertex() {
	float phase = (MODEL_MATRIX[3].x + MODEL_MATRIX[3].y) * 0.013;
	float h = max(0.0, -VERTEX.y);
	VERTEX.x += sin(TIME * speed + phase) * strength * (h / 96.0);
}
"""
	_sway_mat = ShaderMaterial.new()
	_sway_mat.shader = sh
	return _sway_mat


## 12-frame swamp bubble ripple (Dead Swamp pack) — ambient pond life.
static func _bubbles(parent: Node2D, pos: Vector2, rng: RandomNumberGenerator) -> void:
	var sf := SpriteFrames.new()
	sf.remove_animation("default")
	sf.add_animation("blub")
	sf.set_animation_speed("blub", 6.0)
	sf.set_animation_loop("blub", true)
	for i in range(12):
		var at := AtlasTexture.new()
		at.atlas = load("res://assets/art/world/dead_swamp/bubbles_128x128.png")
		at.region = Rect2(float(i % 4) * 32.0, float(int(float(i) / 4.0)) * 32.0, 32.0, 32.0)
		sf.add_frame("blub", at)
	var spr := AnimatedSprite2D.new()
	spr.sprite_frames = sf
	spr.position = pos
	spr.z_index = -6
	spr.play("blub")
	spr.frame = rng.randi_range(0, 11)
	parent.add_child(spr)


## WORLD_PLAN § 40-Second Rule (Witcher-3 law): no point in a zone may be
## farther than MAX_DEAD_PX from an engagement anchor. Grid-samples the zone
## and warns with the worst dead spot so batch QA can backfill micro-POIs.
const MAX_DEAD_PX: float = 1750.0


static func _validate_forty_second_rule(def: Dictionary, w: int, h: int) -> void:
	if bool(def.get("capital", false)):
		return  # capitals are engagement-dense by construction
	var anchors: Array[Vector2] = []
	for lm_v: Variant in def.get("landmarks", []):
		anchors.append((lm_v as Dictionary)["pos"])
	for vg_v: Variant in def.get("vignettes", []):
		anchors.append((vg_v as Dictionary)["pos"])
	for ws_v: Variant in def.get("waystations", []):
		anchors.append((ws_v as Dictionary)["pos"])
	for row_v: Variant in def.get("creature_table", []):
		var area: Rect2 = (row_v as Dictionary).get("area", Rect2())
		anchors.append(area.position + area.size * 0.5)
	if anchors.is_empty():
		push_warning("ZoneBuilder[40s]: zone '%s' has NO engagement anchors" % def.get("id"))
		return
	var worst_d: float = 0.0
	var worst_p := Vector2.ZERO
	var step: float = 400.0
	var y: float = step
	while y < h * TILE - step:
		var x: float = step
		while x < w * TILE - step:
			var p := Vector2(x, y)
			var best: float = INF
			for a in anchors:
				best = minf(best, p.distance_to(a))
			if best > worst_d:
				worst_d = best
				worst_p = p
			x += step
		y += step
	if worst_d > MAX_DEAD_PX:
		push_warning("ZoneBuilder[40s]: zone '%s' FAILS — dead spot at (%d,%d), %d px from nearest anchor (max %d). Backfill micro-POIs."
				% [def.get("id"), int(worst_p.x), int(worst_p.y), int(worst_d), int(MAX_DEAD_PX)])


## Sitting-#1 fix: irregular ground decals kill the tile repeat-grid read.
static func _ground_breakup(parent: Node2D, rng: RandomNumberGenerator, w: int, h: int,
		pal: Dictionary, keep_clear: Array[Rect2]) -> Array[Rect2]:
	var world_w: float = w * TILE
	var world_h: float = h * TILE
	var n: int = int(world_w * world_h / 220000.0)
	var cold: bool = bool(pal.get("cold", false))
	var occupied: Array[Rect2] = []
	var ice_spots: Array[Vector2] = []
	for i in range(n):
		var pos := Vector2(rng.randf_range(40, world_w - 40), rng.randf_range(40, world_h - 40))
		if _in_any(pos, keep_clear) or _in_any(pos, occupied):
			continue
		if cold:
			# Snowbound clutter: rocks, fallen logs, ice patches — never foliage.
			var croll: float = rng.randf()
			if croll < 0.5:
				var crk := Sprite2D.new()
				crk.texture = load(PROPS + "cainos_prop_%02d.png" % rng.randi_range(33, 42))
				crk.position = pos
				crk.z_index = -6
				crk.scale = Vector2.ONE * rng.randf_range(0.5, 0.9)
				crk.modulate = Color(0.86, 0.88, 0.98)
				parent.add_child(crk)
			elif croll < 0.8:
				var lg := Sprite2D.new()
				lg.texture = load("res://assets/art/world/snow/log.png")
				lg.position = pos
				lg.z_index = -6
				parent.add_child(lg)
			else:
				# frozen pools: never stamped near one another, and they own
				# their footprint so scatter can't grow a bush on the ice
				var too_close := false
				for prev: Vector2 in ice_spots:
					if prev.distance_to(pos) < 420.0:
						too_close = true
						break
				if too_close:
					continue
				var ic := Sprite2D.new()
				ic.texture = load("res://assets/art/world/snow/ice_circle.png")
				ic.position = pos
				ic.z_index = -8
				ic.scale = Vector2.ONE * rng.randf_range(0.8, 1.8)
				ic.modulate = Color(1, 1, 1, rng.randf_range(0.7, 0.9))
				parent.add_child(ic)
				ice_spots.append(pos)
				occupied.append(Rect2(pos - Vector2(90, 65) * ic.scale.x, Vector2(180, 130) * ic.scale.x))
			continue
		var roll: float = rng.randf()
		if roll < 0.45:
			var spr := Sprite2D.new()
			spr.texture = load(PROPS + "szadi_prop_%02d.png" % [0, 2, 3, 4, 5][rng.randi_range(0, 4)])
			spr.position = pos
			spr.z_index = -8
			spr.modulate = Color(1, 1, 1, rng.randf_range(0.35, 0.7))
			spr.scale = Vector2.ONE * rng.randf_range(0.6, 1.0)
			parent.add_child(spr)
		elif roll < 0.75:
			var rk := Sprite2D.new()
			rk.texture = load(PROPS + "cainos_prop_%02d.png" % rng.randi_range(33, 42))
			rk.position = pos
			rk.z_index = -6
			rk.scale = Vector2.ONE * rng.randf_range(0.5, 0.9)
			rk.modulate = (pal.get("tree_tint", Color.WHITE) as Color).lightened(0.15)
			parent.add_child(rk)
		else:
			var tf := Sprite2D.new()
			tf.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(9, 14))
			tf.position = pos
			tf.z_index = -6
			parent.add_child(tf)
	return occupied

