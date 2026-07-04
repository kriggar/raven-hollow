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
	"bog": {"tint": Color(1.0, 1.0, 1.0), "patch_chance": 0.0, "tree_tint": Color(0.62, 0.66, 0.55),
		"ground_sheet": "res://assets/art/world/dead_swamp/mud_96x128.png", "ground_cols": 3, "ground_rows": 4},
	"moor": {"tint": Color(0.86, 0.84, 0.74), "patch_chance": 0.10, "tree_tint": Color(0.72, 0.72, 0.60)},
	"wilds": {"tint": Color(0.92, 0.92, 0.84), "patch_chance": 0.08, "tree_tint": Color(0.80, 0.82, 0.68)},
	"farmland": {"tint": Color(1.0, 0.98, 0.88), "patch_chance": 0.06, "tree_tint": Color(0.86, 0.88, 0.72)},
	"deadforest": {"tint": Color(0.82, 0.82, 0.80), "patch_chance": 0.14, "tree_tint": Color(0.95, 0.95, 0.95),
		"tree_set": ["res://assets/art/world/deadforest/birch_dead.png", "res://assets/art/world/deadforest/tree_dark1.png", "res://assets/art/world/deadforest/tree_dark2.png"]},
	"tundra": {"tint": Color(0.82, 0.88, 0.98), "patch_chance": 0.12, "tree_tint": Color(0.66, 0.70, 0.80)},
	"volcanic": {"tint": Color(0.72, 0.58, 0.52), "patch_chance": 0.18, "tree_tint": Color(0.52, 0.42, 0.38)},
	"ridge": {"tint": Color(0.84, 0.86, 0.82), "patch_chance": 0.12, "tree_tint": Color(0.66, 0.70, 0.62)},
	"port": {"tint": Color(0.76, 0.80, 0.82), "patch_chance": 0.10, "tree_tint": Color(0.58, 0.62, 0.62)},
}


static func build_zone(parent: Node2D, def: Dictionary) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(def.get("id", "zone")))
	var tiles_w: int = int(def.get("tiles_w", 256))
	var tiles_h: int = int(def.get("tiles_h", 192))
	var biome: String = str(def.get("biome", "wilds"))
	var pal: Dictionary = _PALETTES.get(biome, _PALETTES["wilds"])

	var keep_clear: Array[Rect2] = []
	for lm_v: Variant in def.get("landmarks", []):
		var lm: Dictionary = lm_v
		var p: Vector2 = lm["pos"]
		keep_clear.append(Rect2(p - Vector2(140, 120), Vector2(280, 240)))
	for vg_v: Variant in def.get("vignettes", []):
		var vg: Dictionary = vg_v
		keep_clear.append(Rect2((vg["pos"] as Vector2) - Vector2(90, 70), Vector2(180, 140)))

	_build_ground(parent, rng, tiles_w, tiles_h, pal, def)
	_build_river(parent, def)
	var road_rects: Array[Rect2] = _build_roads(parent, def, pal.has("ground_sheet"))
	keep_clear.append_array(road_rects)
	_build_warm_ground(parent, rng, def)
	_scatter_vegetation(parent, rng, tiles_w, tiles_h, pal, def, keep_clear)
	_build_landmarks(parent, rng, def)
	_build_vignettes(parent, def)
	_build_waystation(parent, def)
	_build_border_wall(parent, rng, tiles_w, tiles_h, pal, def)

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
	parent.add_child(line)
	# faint moving sheen strip to sell current
	var sheen := Line2D.new()
	sheen.z_index = -7
	for p: Variant in pts:
		sheen.add_point(p as Vector2)
	sheen.width = line.width * 0.35
	sheen.default_color = Color(1.0, 1.0, 1.0, 0.05)
	parent.add_child(sheen)


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
				layer.set_cell(c, 0, Vector2i(rng.randi_range(0, 2), rng.randi_range(4, 5) - 4 + 4))
				if not packed_ground and rng.randf() < 0.6:
					layer.set_cell(c + Vector2i(1, 0), 0, Vector2i(rng.randi_range(4, 7), rng.randi_range(0, 3)))
				rects.append(Rect2(p - Vector2(40, 40), Vector2(80, 80)))
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
		for i in range(4):
			var scratch := ColorRect.new()
			scratch.color = Color(0.62, 0.50, 0.38, 0.5)
			scratch.size = Vector2(rng.randf_range(26, 44), 2)
			scratch.position = pos + Vector2(rng.randf_range(-30, 12), -22 + i * 12)
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
	var tree_set: Array = pal.get("tree_set", [])
	for i in range(n_trees):
		var pos := Vector2(rng.randf_range(60, world_w - 60), rng.randf_range(60, world_h - 60))
		if _in_any(pos, keep_clear):
			continue
		var spr := Sprite2D.new()
		if not tree_set.is_empty():
			spr.texture = load(str(tree_set[rng.randi_range(0, tree_set.size() - 1)]))
		else:
			spr.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(0, 2))
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
				_sprite(parent, "res://assets/art/buildings/house_01.png", pos, true)
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
				_fire(parent, pos)
				for i in range(3):
					_atlas(parent, R_MOUND, pos + Vector2(-50 + i * 50, 34), Color(0.9, 0.86, 0.8))
			"graves":
				for i in range(int(lm.get("count", 6))):
					var gp: Vector2 = pos + Vector2((i % 3) * 40, int(float(i) / 3.0) * 46)
					_atlas(parent, R_STONE_LOW if i % 2 == 0 else R_STONE_TALL, gp, Color(0.85, 0.87, 0.9), true)
			"dolmen":
				_atlas(parent, R_MONOLITH, pos, Color(0.8, 0.82, 0.86), true)
				_atlas(parent, R_STONE_LOW, pos + Vector2(-52, 30), Color(0.8, 0.82, 0.86), true)
				_atlas(parent, R_STONE_LOW, pos + Vector2(52, 30), Color(0.8, 0.82, 0.86), true)
			"bones":
				for i in range(4):
					_atlas(parent, R_BONE_A, pos + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30)), Color(0.95, 0.95, 0.9))
			"pond":
				_pond(parent, pos, rng)
			"stump":
				_swamp_atlas(parent, Rect2(0, 256, 128, 128), pos, true)
			"trunk_hollow":
				_swamp_atlas(parent, Rect2(128, 128, 128, 160), pos, true)
			"manor":
				_sprite(parent, "res://assets/art/buildings/house_04.png", pos, true)
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
				_atlas(parent, Rect2(272, 800, 48, 64), pos + Vector2(0, -34), Color.WHITE, true)
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
	for i in range(3):
		var ln := ColorRect.new()
		ln.color = Color(0.66, 0.56, 0.44, 0.55)
		ln.size = Vector2(34, 2)
		ln.position = pos + Vector2(-16, i * 9)
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


## Ring of edge forest with authored gaps at travel seams (gap rects in def).
static func _build_border_wall(parent: Node2D, rng: RandomNumberGenerator, w: int, h: int,
		pal: Dictionary, def: Dictionary) -> void:
	var gaps: Array = def.get("border_gaps", [])
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
			spr.texture = load(PLANTS + "plant_%02d.png" % rng.randi_range(0, 2))
			spr.position = pos
			spr.offset = Vector2(0, -spr.texture.get_height() * 0.5 + 10)
			spr.modulate = (pal["tree_tint"] as Color).darkened(0.12)
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
				out.append({
					"type": etype,
					"display_name": str(row.get("name", "Creature")),
					"pos": anchor + Vector2(rng.randf_range(-40, 40), rng.randf_range(-30, 30)),
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
