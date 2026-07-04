class_name WildernessBuilder
## Phase C §3 — builds "The Emberfall Road": the wilderness map east of Raven
## Hollow. Reuses TownBuilder's exact terrain/vegetation/prop idioms (Cainos
## grass Ground TileMapLayer, plant_XX vegetation, the _sprite/_atlas_sprite/
## collider/_light helpers) so it reads as the same world — the only importable
## art is the town set plus the three pre-cropped gate PNGs in
## res://assets/art/wilderness/ (the _downloads hyptosis/undead/LPC-tree atlases
## are NOT under res:// and cannot be loaded, so every set-piece is composed from
## the shared asset set).
##
## build(parent) returns the TownBuilder contract PLUS the wilderness-spawn keys
## from the Phase C contract §9 (the builder OWNS spawn positions/config;
## combat.gd instantiates them via Combat.spawn_map_enemies, enemy.gd owns the
## fauna sprite path):
##   {player_spawn, npc_spawns, bounds, stations,
##    camp_pos, listener_pos, gate_pos, enemy_spawns, ambient_spawns}
## Deterministic: fixed-seed RandomNumberGenerator, no Time-based randomness.

const WORLD_TILES_W: int = 70
const WORLD_TILES_H: int = 55
const TILE: int = 32
const SEED: int = 20260704

# Cross-map anchor: the west return waystone lines up with
# MapRegistry.WILD_WEST_ENTRY (80,880) / travel point "west_entry".
const WEST_ENTRY := Vector2(80.0, 880.0)

# --- shared asset roots (identical to TownBuilder) ---
const GRASS_SHEET := "res://assets/art/terrain/cainos_grass.png"
const DECOR := "res://assets/art/decor/lpc_decorations.png"
const PROPS := "res://assets/art/props/"
const PLANTS := "res://assets/art/vegetation/"
const WILD := "res://assets/art/wilderness/"

# --- lpc_decorations.png rects (pixel-verified in town_builder.gd) ---
const R_LANTERN_LIT := Rect2(420, 64, 24, 32)
const R_POLE := Rect2(354, 198, 24, 79)
const R_BIG_TREE := Rect2(448, 292, 64, 122)
const R_SMALL_TREE := Rect2(416, 288, 32, 96)
const R_STATUE_HOOD := Rect2(96, 288, 32, 64)
const R_STATUE_WOLF := Rect2(64, 288, 30, 64)
const R_MOUND := Rect2(160, 128, 32, 62)
const R_COUNTER := Rect2(0, 928, 96, 31)
const R_DRAPE_ORANGE := Rect2(272, 800, 48, 64)
const R_DRAPE_GREEN := Rect2(351, 800, 65, 69)
const FIRE_FRAMES := [
	Rect2(256, 1504, 32, 64), Rect2(288, 1504, 32, 64), Rect2(320, 1504, 32, 64),
	Rect2(352, 1504, 32, 64), Rect2(384, 1504, 32, 64),
]
# Standing / grave stones (dolmen + scattered bones read from the town kit).
const R_MONOLITH := Rect2(96, 0, 64, 96)   # tall broken monument
const R_STONE_TALL := Rect2(0, 0, 32, 62)  # upright slab
const R_STONE_LOW := Rect2(32, 14, 64, 48) # toppled block
const R_BONE_A := Rect2(64, 96, 32, 32)
const R_BONE_B := Rect2(128, 96, 32, 32)

# --- Set-piece anchors (single source of truth; also fed to quests via
#     override_pos in main.gd's wilderness post-build). ---
const CAMP_POS := Vector2(1740.0, 1300.0)     # orc-camp overlook (SE) -> q4_camp
const LISTENER_POS := Vector2(2120.0, 700.0)  # far-east treeline -> q5_treeline
const GATE_POS := Vector2(180.0, 900.0)        # west waystone mouth -> q5_gate
const PLAYER_SPAWN := Vector2(170.0, 900.0)    # just inside the return gate

# Clearings ("rooms") kept free of thicket so the road+set-pieces are reachable.
const CLEAR_GATE := Rect2(0.0, 790.0, 300.0, 210.0)        # west waystone
const CLEAR_CAMP := Rect2(440.0, 640.0, 400.0, 340.0)      # hunter's camp
const CLEAR_DOLMEN := Rect2(940.0, 290.0, 440.0, 320.0)    # standing stones (lore)
const CLEAR_WALLOW := Rect2(800.0, 1070.0, 460.0, 340.0)   # boar wallow
const CLEAR_DEN := Rect2(1620.0, 230.0, 500.0, 340.0)      # wolf den NE (Old Mother)
const CLEAR_ORC := Rect2(1500.0, 1260.0, 520.0, 380.0)     # orc camp SE
const CLEAR_LISTENER := Rect2(1960.0, 540.0, 280.0, 340.0) # listener treeline

static var _light_tex_cache: GradientTexture2D = null


static func build(parent: Node2D) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	parent.y_sort_enabled = true

	var clearings: Array[Rect2] = [
		CLEAR_GATE, CLEAR_CAMP, CLEAR_DOLMEN, CLEAR_WALLOW,
		CLEAR_DEN, CLEAR_ORC, CLEAR_LISTENER,
	]

	var enemy_spawns := _enemy_spawns()
	var ambient_spawns := _ambient_spawns()

	# Keep-clear discs around every combatant/critter so no thicket buries a spawn.
	var discs: Array = []
	for cfg: Dictionary in enemy_spawns:
		discs.append({"c": cfg["pos"], "r": 44.0})
	for cfg: Dictionary in ambient_spawns:
		discs.append({"c": cfg["pos"], "r": 40.0})
	for p: Vector2 in [CAMP_POS, LISTENER_POS, GATE_POS]:
		discs.append({"c": p, "r": 48.0})

	var path_cells: Dictionary = {}
	var ground := _build_ground(rng, path_cells)
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
	_return_gate(props, lights)
	_hunters_camp(props, decals, lights)
	_standing_stones(props, decals)
	_boar_wallow(props, decals)
	_wolf_den(props, decals)
	_orc_camp(props, decals, lights, rng)
	_listener_spot(props, decals)

	# Forest LAST so it fills every non-clearing, non-road, non-spawn pocket into
	# a thicket wall (the collision that shapes the clearings into rooms).
	_border_forest(props, rng, path_cells, clearings)
	_interior_forest(props, rng, path_cells, clearings, discs)
	_grass_tufts(decals, rng, path_cells, clearings)

	# Deferred hunter's-camp reward: grants the hunters_stew recipe scroll once the
	# player is in the tree (build() has no player reference). Static-guarded so a
	# revisit does not re-grant. Non-blocking (§9).
	props.add_child(_HunterScroll.new())

	return {
		"player_spawn": PLAYER_SPAWN,
		"npc_spawns": {},                # no permanent villager cast (Mira is dynamic, §11)
		"bounds": Rect2(0.0, 0.0, float(WORLD_TILES_W * TILE), float(WORLD_TILES_H * TILE)),
		"stations": [],                  # spec: wilderness ships NO crafting stations
		"camp_pos": CAMP_POS,
		"listener_pos": LISTENER_POS,
		"gate_pos": GATE_POS,
		"enemy_spawns": enemy_spawns,
		"ambient_spawns": ambient_spawns,
	}


# -------------------------------------------------------------- SPAWNS ----

static func _enemy_spawns() -> Array[Dictionary]:
	## Combatant config (§9). fauna:true -> enemy.gd builds the LPC animal sprite;
	## orcs omit fauna (they reuse the existing Pixel-Crawler orc sheets). Orc
	## hp/dmg values are the ones relocated from the town camp (§10).
	return [
		# Wolves ×5 — fast, hp26 dmg7. Den cluster NE + a couple roaming inward.
		{"type": "wolf", "display_name": "Wolf", "pos": Vector2(1820.0, 360.0), "hp": 26.0, "damage": 7.0, "speed": 95.0, "patrol_radius": 90.0, "fauna": true},
		{"type": "wolf", "display_name": "Wolf", "pos": Vector2(1910.0, 430.0), "hp": 26.0, "damage": 7.0, "speed": 95.0, "patrol_radius": 90.0, "fauna": true},
		{"type": "wolf", "display_name": "Wolf", "pos": Vector2(1740.0, 450.0), "hp": 26.0, "damage": 7.0, "speed": 95.0, "patrol_radius": 90.0, "fauna": true},
		{"type": "wolf", "display_name": "Wolf", "pos": Vector2(1520.0, 620.0), "hp": 26.0, "damage": 7.0, "speed": 95.0, "patrol_radius": 110.0, "fauna": true},
		{"type": "wolf", "display_name": "Wolf", "pos": Vector2(1650.0, 800.0), "hp": 26.0, "damage": 7.0, "speed": 95.0, "patrol_radius": 110.0, "fauna": true},
		# Bear ×1 mini-boss "Old Mother" at the den — slow, hp120 dmg16.
		{"type": "bear", "display_name": "Old Mother", "pos": Vector2(1860.0, 330.0), "hp": 120.0, "damage": 16.0, "speed": 45.0, "patrol_radius": 70.0, "fauna": true},
		# Boars ×4 near the wallow — hp40 dmg9.
		{"type": "boar", "display_name": "Wild Boar", "pos": Vector2(960.0, 1200.0), "hp": 40.0, "damage": 9.0, "speed": 80.0, "patrol_radius": 70.0, "fauna": true},
		{"type": "boar", "display_name": "Wild Boar", "pos": Vector2(1050.0, 1260.0), "hp": 40.0, "damage": 9.0, "speed": 80.0, "patrol_radius": 70.0, "fauna": true},
		{"type": "boar", "display_name": "Wild Boar", "pos": Vector2(890.0, 1290.0), "hp": 40.0, "damage": 9.0, "speed": 80.0, "patrol_radius": 70.0, "fauna": true},
		{"type": "boar", "display_name": "Wild Boar", "pos": Vector2(1090.0, 1170.0), "hp": 40.0, "damage": 9.0, "speed": 80.0, "patrol_radius": 70.0, "fauna": true},
		# Orc camp SE: 6 orcs + one orc_shaman (quest 4 kill). Values from §10.
		{"type": "orc", "display_name": "Orc Grunt", "pos": Vector2(1680.0, 1420.0), "hp": 40.0, "damage": 7.0, "speed": 60.0, "patrol_radius": 60.0},
		{"type": "orc", "display_name": "Orc Grunt", "pos": Vector2(1820.0, 1420.0), "hp": 40.0, "damage": 7.0, "speed": 60.0, "patrol_radius": 60.0},
		{"type": "orc", "display_name": "Orc Grunt", "pos": Vector2(1750.0, 1520.0), "hp": 40.0, "damage": 7.0, "speed": 60.0, "patrol_radius": 60.0},
		{"type": "orc_warrior", "display_name": "Orc Warrior", "pos": Vector2(1610.0, 1490.0), "hp": 55.0, "damage": 10.0, "speed": 55.0, "patrol_radius": 40.0},
		{"type": "orc_warrior", "display_name": "Orc Warrior", "pos": Vector2(1890.0, 1490.0), "hp": 55.0, "damage": 10.0, "speed": 55.0, "patrol_radius": 40.0},
		{"type": "orc_rogue", "display_name": "Orc Rogue", "pos": Vector2(1700.0, 1380.0), "hp": 35.0, "damage": 8.0, "speed": 70.0, "patrol_radius": 75.0},
		{"type": "orc_shaman", "display_name": "Orc Shaman", "pos": Vector2(1790.0, 1360.0), "hp": 38.0, "damage": 9.0, "speed": 56.0, "patrol_radius": 50.0},
	]


static func _ambient_spawns() -> Array[Dictionary]:
	## Ambient fauna (§9): never fight, flee within flee_radius, group
	## "ambient_fauna" (never "enemies"). No hp/nameplate/target.
	return [
		{"type": "deer", "pos": Vector2(700.0, 500.0), "flee_radius": 60.0, "ambient": true},
		{"type": "deer", "pos": Vector2(1300.0, 900.0), "flee_radius": 60.0, "ambient": true},
		{"type": "deer", "pos": Vector2(520.0, 1200.0), "flee_radius": 60.0, "ambient": true},
		{"type": "deer", "pos": Vector2(1450.0, 640.0), "flee_radius": 60.0, "ambient": true},
		{"type": "fox", "pos": Vector2(900.0, 600.0), "flee_radius": 60.0, "ambient": true},
		{"type": "fox", "pos": Vector2(1200.0, 1330.0), "flee_radius": 60.0, "ambient": true},
		{"type": "rabbit", "pos": Vector2(620.0, 900.0), "flee_radius": 60.0, "ambient": true},
		{"type": "rabbit", "pos": Vector2(1080.0, 480.0), "flee_radius": 60.0, "ambient": true},
		{"type": "rabbit", "pos": Vector2(1560.0, 1150.0), "flee_radius": 60.0, "ambient": true},
		{"type": "bird", "pos": Vector2(820.0, 780.0), "flee_radius": 60.0, "ambient": true},
		{"type": "bird", "pos": Vector2(1150.0, 430.0), "flee_radius": 60.0, "ambient": true},
		{"type": "bird", "pos": Vector2(2050.0, 680.0), "flee_radius": 60.0, "ambient": true},
	]


# -------------------------------------------------------------- GROUND ----

static func _build_ground(rng: RandomNumberGenerator, path_cells: Dictionary) -> TileMapLayer:
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

	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = ts
	layer.y_sort_enabled = false
	layer.z_index = -10

	# Wilder base fill: mostly plain grass (cols 0-3), only ~5% flower/detail
	# (town uses 10%) so the wilderness reads scrubbier.
	for y in range(WORLD_TILES_H):
		for x in range(WORLD_TILES_W):
			var coords := Vector2i(rng.randi_range(0, 3), rng.randi_range(0, 3))
			if rng.randf() < 0.05:
				coords = Vector2i(rng.randi_range(4, 7), rng.randi_range(0, 3))
			layer.set_cell(Vector2i(x, y), 0, coords)

	# Winding W->E dirt road (stone-slab-on-grass path tiles), a snake through the
	# clearings, terminating at the west waystone (row 27 == WEST_ENTRY.y).
	var strips: Array = [
		Rect2i(2, 26, 16, 2),    # west entry -> first bend (through the hunter's-camp edge)
		Rect2i(16, 18, 2, 10),   # bend north
		Rect2i(16, 18, 18, 2),   # north leg (under the dolmen clearing)
		Rect2i(32, 18, 2, 18),   # bend south
		Rect2i(32, 34, 18, 2),   # central leg (through the wallow edge)
		Rect2i(48, 22, 2, 14),   # bend north
		Rect2i(48, 22, 21, 2),   # east leg -> far-east treeline
		Rect2i(56, 12, 2, 11),   # spur north to the wolf den
		Rect2i(54, 22, 2, 19),   # spur south to the orc camp
	]
	for s: Rect2i in strips:
		_paint_path(layer, rng, path_cells, s)
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


# ------------------------------------------------------------ SET PIECES ----

static func _return_gate(props: Node2D, lights: Node2D) -> void:
	# Waystone/return gate at the west edge, composited from the pre-cropped gate
	# PNGs (owned by gate_builder.gd, copied to res://assets/art/wilderness/).
	# Lines up with travel point "west_entry" (WEST_ENTRY / WILD_WEST_ENTRY).
	var gx: float = WEST_ENTRY.x + 16.0
	props.add_child(_sprite(WILD + "gate_arch.png", Vector2(gx, 944.0), 4.0))
	# Flanking wall stubs frame the mouth; opening (center) stays walkable.
	props.add_child(_sprite(WILD + "gate_wall.png", Vector2(gx - 60.0, 948.0), 4.0))
	props.add_child(_sprite(WILD + "gate_wall.png", Vector2(gx + 60.0, 948.0), 4.0))
	props.add_child(_rect_collider(Vector2(gx - 60.0, 900.0), Vector2(48.0, 96.0), Vector2.ZERO))
	props.add_child(_rect_collider(Vector2(gx + 60.0, 900.0), Vector2(48.0, 96.0), Vector2.ZERO))
	# Warm hanging lanterns either side of the arch (into "world_lights").
	props.add_child(_sprite(WILD + "gate_lantern.png", Vector2(gx - 30.0, 872.0), 0.0))
	props.add_child(_sprite(WILD + "gate_lantern.png", Vector2(gx + 30.0, 872.0), 0.0))
	_light(lights, Vector2(gx - 30.0, 872.0), Color(1.0, 0.72, 0.42), 0.8, 90.0)
	_light(lights, Vector2(gx + 30.0, 872.0), Color(1.0, 0.72, 0.42), 0.8, 90.0)


static func _hunters_camp(props: Node2D, decals: Node2D, lights: Node2D) -> void:
	# (a) Hunter's abandoned camp: two canvas tents around a campfire, with a
	# supply crate that stands in for the lootable recipe-scroll chest.
	var c := Vector2(620.0, 810.0)
	_campfire(props, lights, c)
	props.add_child(_tent(c + Vector2(-80.0, -20.0), R_DRAPE_ORANGE))
	props.add_child(_rect_collider(c + Vector2(-80.0, -20.0), Vector2(80.0, 18.0), Vector2(0, -10)))
	props.add_child(_tent(c + Vector2(84.0, 4.0), R_DRAPE_GREEN))
	props.add_child(_rect_collider(c + Vector2(84.0, 4.0), Vector2(80.0, 18.0), Vector2(0, -10)))
	# The "chest": a crate + barrel by the orange tent (the hunters_stew scroll).
	props.add_child(_sprite(PROPS + "szadi_prop_09.png", c + Vector2(-40.0, 26.0), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_08.png", c + Vector2(-18.0, 32.0), 3.0))
	# Firewood pile + a hide drying by the fire.
	props.add_child(_sprite(PROPS + "szadi_prop_10.png", c + Vector2(40.0, 34.0), 3.0))
	_decal(decals, PROPS + "szadi_prop_01.png", c + Vector2(0.0, 8.0))


static func _standing_stones(props: Node2D, decals: Node2D) -> void:
	# (b) Standing-stones dolmen with faint runes — LORE SPOT. A ring of upright
	# slabs around a broken monolith, guardian statue, and worn ground.
	var c := Vector2(1150.0, 430.0)
	props.add_child(_atlas_sprite(R_MONOLITH, c, 6.0))
	props.add_child(_circle_collider(c, 10.0, Vector2(0, -6)))
	var ring: Array = [
		Vector2(-70.0, -6.0), Vector2(70.0, -6.0),
		Vector2(-44.0, 30.0), Vector2(44.0, 30.0),
		Vector2(0.0, -46.0),
	]
	for off: Vector2 in ring:
		props.add_child(_atlas_sprite(R_STONE_TALL, c + off, 4.0))
		props.add_child(_circle_collider(c + off, 7.0, Vector2(0, -3)))
	props.add_child(_atlas_sprite(R_STATUE_HOOD, c + Vector2(0.0, 48.0), 4.0))
	props.add_child(_rect_collider(c + Vector2(0.0, 48.0), Vector2(22.0, 10.0), Vector2(0, -5)))
	# A toppled slab and a couple of boulders leaning at the edge.
	props.add_child(_atlas_sprite(R_STONE_LOW, c + Vector2(-96.0, 40.0), 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_34.png", c + Vector2(104.0, 44.0), 2.0))
	props.add_child(_sprite(PROPS + "cainos_prop_36.png", c + Vector2(-110.0, -30.0), 2.0))
	_decal(decals, PROPS + "szadi_prop_01.png", c + Vector2(0.0, 20.0))


static func _boar_wallow(props: Node2D, decals: Node2D) -> void:
	# (c) Boar wallow clearing: a muddy churned hollow with reeds and rocks.
	var c := Vector2(1000.0, 1230.0)
	_decal(decals, PROPS + "szadi_prop_01.png", c)
	_decal(decals, PROPS + "szadi_prop_01.png", c + Vector2(60.0, 20.0))
	_decal(decals, PROPS + "szadi_prop_01.png", c + Vector2(-64.0, 10.0))
	for off: Vector2 in [Vector2(-90.0, -30.0), Vector2(92.0, -18.0), Vector2(20.0, 46.0)]:
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % ((int(absf(off.x)) % 6) + 3), c + off, 3.0))
	props.add_child(_sprite(PROPS + "cainos_prop_35.png", c + Vector2(-40.0, -40.0), 2.0))
	props.add_child(_sprite(PROPS + "cainos_prop_38.png", c + Vector2(110.0, 30.0), 2.0))


static func _wolf_den(props: Node2D, decals: Node2D) -> void:
	# (d) Wolf den NE: gnarled dead trees and scattered bones (Old Mother lairs
	# here — her spawn is in _enemy_spawns).
	var c := Vector2(1850.0, 380.0)
	for off: Vector2 in [Vector2(-90.0, -20.0), Vector2(96.0, 10.0), Vector2(-30.0, -60.0)]:
		props.add_child(_atlas_sprite(R_SMALL_TREE, c + off, 4.0))
		props.add_child(_circle_collider(c + off, 6.0, Vector2(0, -3)))
	props.add_child(_atlas_sprite(R_BIG_TREE, c + Vector2(120.0, -40.0), 6.0))
	props.add_child(_circle_collider(c + Vector2(120.0, -40.0), 10.0, Vector2(0, -6)))
	# Bones littering the den mouth (no colliders — walkable gore).
	for off: Vector2 in [Vector2(-20.0, 20.0), Vector2(30.0, 34.0), Vector2(0.0, 48.0)]:
		_decal_rect(decals, R_BONE_A if int(absf(off.x)) % 2 == 0 else R_BONE_B, c + off)
	_decal_rect(decals, R_MOUND, c + Vector2(-56.0, 40.0))
	props.add_child(_sprite(PROPS + "cainos_prop_40.png", c + Vector2(60.0, 48.0), 2.0))


static func _orc_camp(props: Node2D, decals: Node2D, lights: Node2D, rng: RandomNumberGenerator) -> void:
	# (e) Bigger orc camp SE (relocated from town): tents, two campfires, banner
	# poles. The 6 orcs + shaman are in _enemy_spawns.
	var c := Vector2(1750.0, 1450.0)
	_campfire(props, lights, c + Vector2(0.0, -30.0))
	_campfire(props, lights, c + Vector2(90.0, 50.0))
	# War tents around the fires.
	for t: Array in [[Vector2(-120.0, -10.0), R_DRAPE_GREEN], [Vector2(110.0, -34.0), R_DRAPE_ORANGE], [Vector2(-60.0, 70.0), R_DRAPE_GREEN]]:
		props.add_child(_tent(c + (t[0] as Vector2), t[1] as Rect2))
		props.add_child(_rect_collider(c + (t[0] as Vector2), Vector2(80.0, 18.0), Vector2(0, -10)))
	# Banner poles (bare poles with a drape lashed on) marking the camp bounds.
	for bp: Vector2 in [Vector2(-150.0, 30.0), Vector2(150.0, 20.0), Vector2(0.0, -100.0)]:
		props.add_child(_banner(c + bp))
		props.add_child(_circle_collider(c + bp, 4.0, Vector2(0, -2)))
	# Loot/refuse scattered by the fires.
	props.add_child(_sprite(PROPS + "szadi_prop_30.png", c + Vector2(40.0, -12.0), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_25.png", c + Vector2(-30.0, 44.0), 3.0))
	props.add_child(_sprite(PROPS + "szadi_prop_19.png", c + Vector2(120.0, 70.0), 3.0))
	_decal(decals, PROPS + "szadi_prop_01.png", c + Vector2(0.0, -30.0))
	# A worn banner-lit outpost light over the camp centre.
	_light(lights, c + Vector2(0.0, -30.0), Color(1.0, 0.55, 0.28), 0.9, 130.0)


static func _listener_spot(props: Node2D, decals: Node2D) -> void:
	# (f) Far-east treeline "Listener" spot (quest 5). A hush in the trees where
	# Mira stands at night — kept clear; the treeline crowds behind it.
	var c := LISTENER_POS
	for off: Vector2 in [Vector2(-70.0, -50.0), Vector2(78.0, -40.0), Vector2(0.0, -80.0), Vector2(110.0, 20.0)]:
		props.add_child(_atlas_sprite(R_SMALL_TREE, c + off, 4.0))
		props.add_child(_circle_collider(c + off, 6.0, Vector2(0, -3)))
	# A single pale marker stone where she listens.
	props.add_child(_atlas_sprite(R_STONE_TALL, c + Vector2(-6.0, 10.0), 3.0))
	_decal(decals, PROPS + "szadi_prop_00.png", c + Vector2(20.0, -6.0))


# ------------------------------------------------------------ VEGETATION ----

static func _border_forest(props: Node2D, rng: RandomNumberGenerator, path_cells: Dictionary, clearings: Array[Rect2]) -> void:
	# Dense 2-deep tree wall around the whole map edge (TownBuilder idiom). The
	# inner row carries colliders; the outer row is scenery. Skips the road mouth
	# and the west waystone opening.
	var w := float(WORLD_TILES_W * TILE)
	var h := float(WORLD_TILES_H * TILE)
	var x: float = 44.0
	while x < w - 40.0:
		var jx: float = x + rng.randf_range(-14.0, 14.0)
		_forest_tree(props, rng, Vector2(jx, rng.randf_range(26.0, 46.0)), false, path_cells, clearings)
		_forest_tree(props, rng, Vector2(jx + 38.0, rng.randf_range(74.0, 104.0)), true, path_cells, clearings)
		_forest_tree(props, rng, Vector2(jx, h - rng.randf_range(4.0, 24.0)), false, path_cells, clearings)
		_forest_tree(props, rng, Vector2(jx + 38.0, h - rng.randf_range(52.0, 82.0)), true, path_cells, clearings)
		x += 76.0 + rng.randf_range(-10.0, 10.0)
	var y: float = 140.0
	while y < h - 130.0:
		_forest_tree(props, rng, Vector2(rng.randf_range(16.0, 38.0), y), false, path_cells, clearings)
		_forest_tree(props, rng, Vector2(rng.randf_range(64.0, 96.0), y + 40.0), true, path_cells, clearings)
		_forest_tree(props, rng, Vector2(w - rng.randf_range(16.0, 38.0), y), false, path_cells, clearings)
		_forest_tree(props, rng, Vector2(w - rng.randf_range(64.0, 96.0), y + 40.0), true, path_cells, clearings)
		y += 82.0 + rng.randf_range(-10.0, 10.0)


static func _interior_forest(props: Node2D, rng: RandomNumberGenerator, path_cells: Dictionary, clearings: Array[Rect2], discs: Array) -> void:
	# Fills every non-clearing, non-road, non-spawn pocket with colliding thicket
	# so the clearings become distinct rooms joined only by the road. Jittered
	# grid keeps it deterministic and reasonably dense without exploding node
	# count. Every interior tree collides (it is a wall).
	var w := float(WORLD_TILES_W * TILE)
	var h := float(WORLD_TILES_H * TILE)
	var gy: float = 120.0
	while gy < h - 100.0:
		var gx: float = 120.0
		while gx < w - 100.0:
			var p := Vector2(gx + rng.randf_range(-16.0, 16.0), gy + rng.randf_range(-16.0, 16.0))
			gx += 62.0
			if rng.randf() < 0.14:
				continue  # occasional gap so thickets read organic
			if _blocked(p, path_cells, clearings, discs):
				continue
			_forest_tree(props, rng, p, true, path_cells, clearings)
		gy += 60.0


static func _forest_tree(props: Node2D, rng: RandomNumberGenerator, pos: Vector2, collide: bool, path_cells: Dictionary, clearings: Array[Rect2]) -> void:
	var cell := Vector2i(int(pos.x / 32.0), int(pos.y / 32.0))
	if path_cells.has(cell):
		return
	for c: Rect2 in clearings:
		if c.has_point(pos):
			return
	# Mix leafy Cainos trees (plant_00..02) with the gnarled sapling atlas so the
	# wood reads wild + dead. Consume the rng draws regardless for determinism.
	var roll: float = rng.randf()
	var variant: int = rng.randi_range(0, 2) if roll < 0.78 else -1
	if variant >= 0:
		props.add_child(_sprite(PLANTS + "plant_%02d.png" % variant, pos, 10.0))
	else:
		props.add_child(_atlas_sprite(R_SMALL_TREE, pos, 4.0))
	if collide:
		props.add_child(_circle_collider(pos, 7.0, Vector2(0, -4)))


static func _grass_tufts(decals: Node2D, rng: RandomNumberGenerator, path_cells: Dictionary, clearings: Array[Rect2]) -> void:
	# Wilder ground cover: denser tufts than town (skipping road cells; clearings
	# still get some so they don't read as bald).
	var tufts: int = 0
	var tries: int = 0
	while tufts < 180 and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(48.0, float(WORLD_TILES_W * TILE) - 48.0),
				rng.randf_range(48.0, float(WORLD_TILES_H * TILE) - 48.0))
		var cell := Vector2i(int(p.x / 32.0), int(p.y / 32.0))
		if path_cells.has(cell):
			continue
		var idx: int = rng.randi_range(9, 14)
		_decal(decals, PLANTS + "plant_%02d.png" % idx, p)
		tufts += 1


static func _blocked(pos: Vector2, path_cells: Dictionary, clearings: Array[Rect2], discs: Array) -> bool:
	var cell := Vector2i(int(pos.x / 32.0), int(pos.y / 32.0))
	if path_cells.has(cell):
		return true
	for c: Rect2 in clearings:
		if c.has_point(pos):
			return true
	for d: Dictionary in discs:
		if pos.distance_to(d["c"]) <= float(d["r"]):
			return true
	return false


# --------------------------------------------------------------- HELPERS ----

static func _campfire(props: Node2D, lights: Node2D, pos: Vector2) -> void:
	props.add_child(_anim_sprite(FIRE_FRAMES, 8.0, pos, 4.0))
	props.add_child(_circle_collider(pos, 8.0, Vector2(0, -5)))
	_light(lights, pos + Vector2(0.0, -14.0), Color(1.0, 0.6, 0.3), 1.0, 100.0)


static func _tent(pos: Vector2, drape: Rect2) -> Node2D:
	# A lean-to canvas over a low counter (reuses the market-stall composition —
	# reads as a hunter/orc tent).
	var tent := Node2D.new()
	tent.position = pos
	var base := Sprite2D.new()
	base.texture = _region(DECOR, R_COUNTER)
	base.centered = false
	base.offset = Vector2(-48.0, -31.0)
	tent.add_child(base)
	var canvas := Sprite2D.new()
	canvas.texture = _region(DECOR, drape)
	canvas.centered = false
	canvas.offset = Vector2(drape.size.x * -0.5, -drape.size.y)
	canvas.position = Vector2(0.0, -28.0)
	tent.add_child(canvas)
	return tent


static func _banner(pos: Vector2) -> Node2D:
	# Bare pole with a drape lashed on — a crude war-banner for the orc camp.
	var banner := Node2D.new()
	banner.position = pos
	var pole := Sprite2D.new()
	pole.texture = _region(DECOR, R_POLE)
	pole.centered = false
	pole.offset = Vector2(-12.0, -77.0)
	banner.add_child(pole)
	var cloth := Sprite2D.new()
	cloth.texture = _region(DECOR, R_DRAPE_ORANGE)
	cloth.centered = false
	cloth.offset = Vector2(-24.0, -74.0)
	banner.add_child(cloth)
	return banner


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


static func _light(lights: Node2D, pos: Vector2, color: Color, energy: float, radius: float) -> PointLight2D:
	# Ambience light: registered into "world_lights" (day/night contract §8) with
	# its base energy cached in meta so DayNight can ramp it at night.
	var l := PointLight2D.new()
	l.texture = _light_texture()
	l.position = pos
	l.color = color
	l.energy = energy
	l.texture_scale = radius / 128.0
	l.add_to_group("world_lights")
	l.set_meta("dn_base_energy", energy)
	lights.add_child(l)
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


# ------------------------------------------------------- DEFERRED REWARD ----

class _HunterScroll extends Node:
	## Grants the hunters_stew recipe scroll to the player once (per session) after
	## the world enters the tree — build() has no player reference, and change_map
	## re-parents the player a frame after the world is added. Static-guarded so a
	## wilderness revisit does not re-grant. Fully non-blocking (§9).
	static var _granted: bool = false

	func _ready() -> void:
		var tree := get_tree()
		if tree != null:
			tree.create_timer(0.35).timeout.connect(_try_grant)

	func _try_grant() -> void:
		if _HunterScroll._granted:
			return
		var tree := get_tree()
		if tree == null:
			return
		var pl := tree.get_first_node_in_group("player")
		if pl == null:
			return
		var inv_v: Variant = pl.get("inventory")
		if not (inv_v is Inventory):
			return
		_HunterScroll._granted = true
		Crafting.grant(inv_v, "recipe_hunters_stew", 1)
